//
//  AtomicSheet.swift
//  
//
//  Created by Adhiraj Singh on 5/11/20.
//

import Foundation
import NIO
import AsyncHTTPClient

public class AtomicSheet: SheetInteractable {
	
	public let spreadsheetId: String
	public let authenticator: Authenticator?
	public let sheetTitle: String
	/// How long after an error should a re-upload be attempted
	public var reuploadInterval: TimeAmount = .seconds(30)
	/// How long to wait after an operation before attempting an upload
	public var uploadInterval: TimeAmount = .seconds(1)
	
	public weak var delegate: AtomicSheetDelegate?
	private(set) public var isSheetLoaded = false
	
	private var isShutdown = false
	
	private var sheetId: Int!
	
	private(set) public var end: Sheet.Location = .cell(0, 0)
	private(set) public var data: [[String]] = .init()
	
	private var operationQueue = [Spreadsheet.Operation]()
	internal var uploading = false
	
	private let onLoad: EventLoopPromise<Void>
	private var pendingOperationChain: EventLoopFuture<Void>
	
	private let start: Sheet.Location = .cell(0, 0)
	private let serialQueue: DispatchQueue = .init(label: "write_queue", attributes: [])
	
	public let client: HTTPClient!
	
	public init (spreadsheetId: String,
				 sheetTitle: String,
				 using authenticator: Authenticator,
				 client: HTTPClient,
				 delegate: AtomicSheetDelegate? = nil) {
		self.spreadsheetId = spreadsheetId
		self.authenticator = authenticator
		self.sheetTitle = sheetTitle
		self.delegate = delegate
		self.client = client
		
		onLoad = client.eventLoopGroup.next().makePromise()
		operationQueue = [.load()]
		pendingOperationChain = onLoad.futureResult
		_ = beginUpload()
	}
	public func get () -> EventLoopFuture<[[String]]> {
		executeInPendingChain { self.data }
	}
	public func operationsLeft () -> EventLoopFuture<Int> {
		executeInPendingChain { self.operationQueue.count }
	}
	func executeInPendingChain <T> (_ block: @escaping () throws -> T) -> EventLoopFuture<T> {
		if isShutdown { fatalError("operation called on shutdown sheet") }
		
		let promise = client.eventLoopGroup.next().makePromise(of: T.self)
		serialQueue.async {
			let op = self.pendingOperationChain
						.map {
							do {
								promise.succeed(try block())
							} catch {
								promise.fail(error)
							}
						}
			self.pendingOperationChain = op
		}
		return promise.futureResult
	}
	func executeInPendingChain <T> (_ block: @escaping () throws -> EventLoopFuture<T>) -> EventLoopFuture<T> {
		let promise = client.eventLoopGroup.next().makePromise(of: T.self)
		serialQueue.async {
			let op = self.pendingOperationChain.flatMapThrowing (block)
				.map (promise.succeed)
				.flatMapErrorThrowing(promise.fail)
			self.pendingOperationChain = op
		}
		return promise.futureResult
	}
	
	public func operate (using block: @escaping (AtomicSheet) throws -> Void) -> EventLoopFuture<Void> {
		executeInPendingChain { () -> Void in
			try block(self)
			if !self.uploading {
				self.scheduleUpload(in: self.uploadInterval)
			}
		}
	}
	public func append (rows: [[String]]) throws {
		try operate(op: .appendCells(sheetId: sheetId, rows: rows)) {
			if rows.filter({$0.count-1 >= self.end.col!}).count > 0 {
				throw OperationError.outOfBounds
			}
			data.append(contentsOf: rows)
			end = end + (0, rows.count)
		}
	}
	public func append (dimension dim: Sheet.Dimension, size: Int) throws {
		try operate(op: .append(sheetId: sheetId, size: size, dimension: dim)) {
			if dim == .columns {
				end = end + (size, 0)
			} else {
				end = end + (0, size)
			}
		}
	}
	public func delete (dimension dim: Sheet.Dimension, range: Range<Int>) throws {
		try operate(op: .delete(sheetId: sheetId, range: range, dimension: dim)) {
			let count = range.upperBound-range.lowerBound
			if dim == .columns {
				for i in 0..<data.count {
					data[i].removeSubrange(range)
				}
				end = end + (-count, 0)
			} else {
				data.removeSubrange(range)
				end = end + (0, -count)
			}
		}
	}
	public func insert (dimension dim: Sheet.Dimension, range: Range<Int>) throws {
		try operate(op: .insert(sheetId: sheetId, range: range, dimension: dim)) {
			let count = range.upperBound-range.lowerBound
			if dim == .columns {
				for i in 0..<data.count {
					data[i].insert(contentsOf: [String](repeating: "", count: count), at: range.lowerBound)
				}
				end = end + (count, 0)
			} else {
				data.insert(contentsOf: (0..<count).map{ _ in [String]() }, at: range.lowerBound)
				end = end + (0, count)
			}
		}
	}
	public func move (dimension dim: Sheet.Dimension, range: Range<Int>, to index: Int) throws {
		try operate(op: .move(sheetId: sheetId, range: range, to: index, dimension: dim)) {
			let count = range.upperBound-range.lowerBound
			if dim == .columns {
				fatalError("not implemented yet")
			} else {
				if range.contains(index) {
					throw OperationError.invalidMove
				}
				if !data.indices.contains(range.lowerBound) ||
				   !data.indices.contains(range.upperBound) ||
				   !data.indices.contains(index) {
					throw OperationError.outOfBounds
				}
				let rows = range.map { _ in data.remove(at: range.lowerBound) }
				
				if index < range.lowerBound {
					self.data.insert(contentsOf: rows, at: index)
				} else if index > range.upperBound {
					self.data.insert(contentsOf: rows, at: index-count)
				}

			}
		}
	}
	public func set (rows: [[String]], at loc: Sheet.Location) throws {
		try operate(op: .updateCells(sheetId: sheetId, rows: rows, start: loc)) {
			let celledLoc = loc.celled()
			if celledLoc.row!+rows.count-1 >= end.row! {
				throw OperationError.outOfBounds
			}
			if celledLoc.row!+rows.count > data.count {
				let rem = celledLoc.row!+rows.count - data.count
				data.append(contentsOf: [[String]](repeating: [], count: rem))
			}
			for i in 0..<rows.count {
				let di = i+celledLoc.row!
				let maxCol = celledLoc.col!+rows[i].count
				if maxCol-1 >= end.col! {
					throw OperationError.outOfBounds
				}
				if maxCol > data[di].count {
					data[di].append(contentsOf: [String](repeating: "", count: maxCol-data[di].count))
				}
				for j in celledLoc.col!..<data[di].count {
					data[di][j] = rows[i][j-celledLoc.col!]
				}
			}
		}
	}
	public func clear () throws {
		try operate(op: .clear(sheetId: sheetId)) { data.removeAll() }
	}
	public func shutdownSync () throws {
		try executeInPendingChain({ self.isShutdown = true }).wait()
	}
	
	func operate (op: Spreadsheet.Operation, _ exec: () throws -> Void) throws {
		if isShutdown { fatalError("operation called on shut down sheet") }
		try exec ()
		operationQueue.append(op)
	}
	
	func scheduleUpload (in time: TimeAmount) {
		if isShutdown {
			return
		}
		_ = client.eventLoopGroup.next()
		.scheduleTask(in: time, { })
		.futureResult
		.flatMap { self.beginUpload() }
	}
	func beginUpload () -> EventLoopFuture<Void> {
		let promise = client.eventLoopGroup.next().makePromise(of: Void.self)
		serialQueue.async {
			if !self.uploading, self.operationQueue.count > 0 {
				self.uploading = true
				
				let future = self.upload(till: self.operationQueue.count, ops: self.operationQueue)
				.flatMap { index -> EventLoopFuture<Void> in
					self.operationQueue.removeSubrange(0..<index)
					self.uploading = false
					return self.beginUpload()
				}
				future.whenFailure(promise.fail)
				future.whenSuccess(promise.succeed)
			} else {
				promise.succeed(())
			}
		}
		return promise.futureResult
	}
	private func upload (till index: Int, ops: [Spreadsheet.Operation]) -> EventLoopFuture<Int> {
		let workTill: Int
		let future: EventLoopFuture<Void>
		
		if ops.first!.load == true {
			workTill = 1
			future = load()
		} else {
			workTill = index
			future = batchUpdate(operations: .init(requests: ops)).map { _ in }
		}
		
		let workedOps = Array(ops[0..<workTill])
		delegate?.uploadWillBegin(sheetTitle, operations: workedOps)
		
		future.whenSuccess { self.delegate?.uploadDidSucceed(self.sheetTitle, operations: workedOps) }
		future.whenFailure {
			//print ("error: \($0)")
			self.delegate?.uploadDidFail(self.sheetTitle, operations: workedOps, error: $0)
			self.uploading = false
			self.scheduleUpload(in: self.reuploadInterval)
		}
		return future.map { workTill }
	}
	private func load () -> EventLoopFuture<Void> {
		var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
		comps.queryItems = [
			URLQueryItem(name: "fields", value: "sheets.properties,sheets.data.rowData.values.userEnteredValue"),
			URLQueryItem(name: "ranges", value: sheetTitle),
		]
		let url = comps.url!
		return authenticating()
			.flatMapThrowing { try self.client.execute(url: url, headers: $0, errorType: ErrorResponse.self) }
			.flatMapErrorThrowing { err -> SheetsObject in
				if let error = err as? ErrorResponse, error.error.code == 400 {
					return SheetsObject(sheets: [])
				}
				throw err
			}
			.flatMapThrowing { sheets -> EventLoopFuture<Sheet> in
				if let sheet = sheets.sheets.first {
					return self.client!.eventLoopGroup.next().makeSucceededFuture(sheet)
				} else {
					return self.batchUpdate(.addSheet(title: self.sheetTitle, grid: nil))
						.map { Sheet(properties: $0.replies.first!.addSheet!.properties!, data: nil) }
				}
			}
			.map {
				self.sheetId = $0.properties.sheetId
				self.data = $0.data?[0].rowData?.map { $0.values.map { $0.toString() } } ?? []
				self.end = .cell($0.properties.gridProperties!.columnCount, $0.properties.gridProperties!.rowCount)
				self.isSheetLoaded = true
				self.onLoad.succeed(())
			}
	}

	private struct SheetsObject: Codable {
		let sheets: [Sheet]
	}
}
public enum OperationError: Error {
	case outOfBounds
	case invalidMove
}
public protocol AtomicSheetDelegate: class {
	func uploadWillBegin (_ sheet: String, operations: [Spreadsheet.Operation])
	func uploadDidSucceed (_ sheet: String, operations: [Spreadsheet.Operation])
	func uploadDidFail (_ sheet: String, operations: [Spreadsheet.Operation], error: Error)
}
