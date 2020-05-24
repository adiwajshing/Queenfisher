//
//  AtomicSheet.swift
//  
//
//  Created by Adhiraj Singh on 5/11/20.
//

import Foundation
import Promises

public class AtomicSheet: SheetInteractable {
	
	public let spreadsheetId: String
	public let authenticator: Authenticator?
	public let sheetTitle: String
	/// How long after an error should a re-upload be attempted
	public var reuploadInterval: DispatchTimeInterval = .seconds(30)
	/// How long to wait after an operation before attempting an upload
	public var uploadInterval: DispatchTimeInterval = .seconds(1)
	
	public weak var delegate: AtomicSheetDelegate?
	private(set) public var isSheetLoaded = false
	
	private var sheetId: Int!
	
	private(set) public var end: Sheet.Location = .cell(0, 0)
	private(set) public var data: [[String]] = .init()
	
	private var operationQueue = [Sheet.Operation]()
	internal var uploading = false
	
	private let onLoad = Promise<Void>.pending()
	private var pendingOperationChain: Promise<Void>
	
	private let start: Sheet.Location = .cell(0, 0)
	private let serialQueue: DispatchQueue = .init(label: "write_queue", attributes: [])
	public let queue: DispatchQueue = .global()
	
	public init (spreadsheetId: String, sheetTitle: String,
				 using authenticator: Authenticator, delegate: AtomicSheetDelegate? = nil) {
		self.spreadsheetId = spreadsheetId
		self.authenticator = authenticator
		self.sheetTitle = sheetTitle
		self.delegate = delegate
		
		operationQueue = [.load()]
		pendingOperationChain = onLoad
		_ = beginUpload()
	}
	public func get () -> Promise<[[String]]> {
		executeInPendingChain { self.data }
	}
	public func operationsLeft () -> Promise<Int> {
		executeInPendingChain { self.operationQueue.count }
	}
	func executeInPendingChain <T> (_ block: @escaping () throws -> T) -> Promise<T> {
		Promise(on: serialQueue, { (fulfill, reject) in
			let promise = self.pendingOperationChain
						.then(on: self.serialQueue) {
							do {
								fulfill(try block())
							} catch {
								reject(error)
							}
						}
			
			self.pendingOperationChain = promise.then(on: self.queue) { _ in }
		})
	}
	func executeInPendingChain <T> (_ block: @escaping () throws -> Promise<T>) -> Promise<T> {
		Promise(on: serialQueue, { (fulfill, reject) in
			let promise = self.pendingOperationChain
						.then(on: self.serialQueue) { try block() }
						.then(on: self.serialQueue) { fulfill($0) }
						.catch(on: self.serialQueue, reject)
			
			self.pendingOperationChain = promise.then(on: self.queue) { _ in }
		})
	}
	
	
	public func operate (using block: @escaping (AtomicSheet) throws -> Void) -> Promise<Void> {
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
	func operate (op: Sheet.Operation, _ exec: () throws -> Void) throws {
		try exec ()
		operationQueue.append(op)
	}
	
	func scheduleUpload (in time: DispatchTimeInterval) {
		queue.asyncAfter(deadline: .now() + time, execute: { _ = self.beginUpload() })
	}
	func beginUpload () -> Promise<Void> {
		Promise(on: serialQueue) { (fulfill, reject) in
			if !self.uploading, self.operationQueue.count > 0 {
				self.uploading = true
				try self.upload(till: self.operationQueue.count, ops: self.operationQueue)
					.then(on: self.serialQueue) { index -> Promise<Void> in
						self.operationQueue.removeSubrange(0..<index)
						self.uploading = false
						return self.beginUpload()
					}
			} else {
				fulfill(())
			}
		}
	}
	private func upload (till index: Int, ops: [Sheet.Operation]) throws -> Promise<Int> {
		let workTill: Int
		let promise: Promise<Void>
		
		if ops.first!.load == true {
			workTill = 1
			promise = load()
		} else {
			workTill = index
			promise = batchUpdate(operations: .init(requests: ops)).then(on: queue) { _ in }
		}
		
		let workedOps = Array(ops[0..<workTill])
		delegate?.uploadWillBegin(sheetTitle, operations: workedOps)
		return promise
			.then(on: serialQueue) { _ -> Int in
				self.delegate?.uploadDidSucceed(self.sheetTitle, operations: workedOps)
				return workTill
			}
			.catch(on: serialQueue) {
				//print ("error: \($0)")
				self.delegate?.uploadDidFail(self.sheetTitle, operations: workedOps, error: $0)
				self.uploading = false
				self.scheduleUpload(in: self.reuploadInterval)
			}
	}
	private func load () -> Promise<Void> {
		var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
		comps.queryItems = [
			URLQueryItem(name: "fields", value: "sheets.properties,sheets.data.rowData.values.userEnteredValue"),
			URLQueryItem(name: "ranges", value: sheetTitle),
		]
		let url = comps.url!
		return authenticating()
			.then(on: queue) { try url.httpRequest(headers: $0, decoder: JSONDecoder(), errorType: Sheet.ErrorResponse.self) }
			.recover(on: queue) { err throws -> SheetsObject in
				if let error = err as? Sheet.ErrorResponse, error.error.code == 400 {
					return SheetsObject(sheets: [])
				}
				throw err
			}
			.then(on: queue) { sheets -> Promise<Sheet> in
				if let sheet = sheets.sheets.first {
					return .init(sheet)
				} else {
					return self.batchUpdate(.addSheet(title: self.sheetTitle, grid: nil))
						.then(on: self.queue) { Sheet(properties: $0.replies.first!.addSheet!.properties!, data: nil) }
				}
			}
			.then(on: queue) {
				self.sheetId = $0.properties.sheetId
				self.data = $0.data?[0].rowData?.map { $0.values.map { $0.toString() } } ?? []
				self.end = .cell($0.properties.gridProperties!.columnCount, $0.properties.gridProperties!.rowCount)
				self.isSheetLoaded = true
				self.onLoad.fulfill(())
				return .init(())
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
	func uploadWillBegin (_ sheet: String, operations: [Sheet.Operation])
	func uploadDidSucceed (_ sheet: String, operations: [Sheet.Operation])
	func uploadDidFail (_ sheet: String, operations: [Sheet.Operation], error: Error)
}
