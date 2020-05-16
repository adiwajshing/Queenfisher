//
//  AtomicSheet.swift
//  
//
//  Created by Adhiraj Singh on 5/11/20.
//

import Foundation
import Promises
import Atomics

public class AtomicSheet <Auth: Authenticator> {
	public let spreadsheetId: String
	public let authenticator: Auth
	public let sheetTitle: String
	public let syncInterval: DispatchTimeInterval
	private(set) public weak var delegate: AtomicSheetDelegate!
	private(set) public var isSheetLoaded = false
	
	private(set) var spreadsheet: Spreadsheet <Auth>!
	
	private var sheetId: Int!
	
	private var end: Sheet.Location = .cell(0, 0)
	private var data: [[String]] = .init()
	
	private var uploading = false
	
	private let onLoad = Promise<Void>.pending()
	private var pendingOperationChain: Promise<Void>
	
	private let start: Sheet.Location = .cell(0, 0)
	private let queue: DispatchQueue = .global()
	private let writeQueue: DispatchQueue = .init(label: "write", attributes: [])
	let operationQueue = AtomicMutablePointer<[SheetOperation]>(.init())
	
	public init (spreadsheetId: String, sheetTitle: String,
				 using authenticator: Auth, syncInterval: DispatchTimeInterval,
				 delegate: AtomicSheetDelegate? = nil) {
		self.spreadsheetId = spreadsheetId
		self.authenticator = authenticator
		self.sheetTitle = sheetTitle
		self.syncInterval = syncInterval
		self.delegate = delegate
		
		operationQueue.syncPointee = [.load]
		pendingOperationChain = onLoad
		_ = beginUpload()
	}
	public init (spreadsheet: Spreadsheet<Auth>, sheetTitle: String,
				 syncInterval: DispatchTimeInterval, delegate: AtomicSheetDelegate? = nil) {
		self.spreadsheetId = spreadsheet.spreadsheetId
		self.authenticator = spreadsheet.authenticator!
		self.sheetTitle = sheetTitle
		self.syncInterval = syncInterval
		self.delegate = delegate
		self.spreadsheet = spreadsheet
		
		operationQueue.syncPointee = [.load]
		pendingOperationChain = onLoad
		_ = beginUpload()
	}
	public func get (timeout: TimeInterval = 10) -> Promise<[[String]]> {
		onLoad
		.then(on: queue) { self.operationQueue.map(using: { _ in self.data }) }
		.timeout(on: queue, timeout)
	}
	public func operate (_ op: SheetOperation) {
		operate (using: { _ in [op] })
	}
	public func operate (using block: @escaping (inout [[String]]) throws -> [SheetOperation])  {
		writeQueue.async (flags: .barrier) {
			self.pendingOperationChain = self.pendingOperationChain.then(on: self.queue) {
				self.operationQueue.use { queue in
					let ops = try block (&self.data)
					for op in ops {
						try self.applyOperation(op)
						queue.append(op)
					}
				}
			}
		}
	}
	private func applyOperation (_ op: SheetOperation) throws {
		switch op {
		case .appendRows(let rows):
			if rows.filter({$0.count >= self.end.col!}).count > 0 {
				throw OperationError.outOfBounds
			}
			data.append(contentsOf: rows)
			end = end + (0, rows.count)
			break
		case .delete(let dim, let range):
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
			break
		case .insert(let dim, let range):
			let count = range.upperBound-range.lowerBound
			if dim == .columns {
				for i in 0..<data.count {
					data[i].insert(contentsOf: [String](repeating: "", count: count), at: range.lowerBound)
				}
				end = end + (count, 0)
			} else {
				data.insert(contentsOf: [[String]](repeating: [], count: count), at: range.lowerBound)
				end = end + (0, count)
			}
			break
		case .set(let loc, let rows):
			let celledLoc = loc.celled()
			if celledLoc.row!+rows.count >= end.row! {
				throw OperationError.outOfBounds
			}
			if celledLoc.row!+rows.count > data.count {
				let rem = celledLoc.row!+rows.count - data.count
				data.append(contentsOf: [[String]](repeating: [], count: rem))
			}
			for i in 0..<rows.count {
				let di = i+celledLoc.row!
				let maxCol = celledLoc.col!+rows[i].count
				if maxCol >= end.col! {
					throw OperationError.outOfBounds
				}
				if maxCol > data[di].count {
					data[di].append(contentsOf: [String](repeating: "", count: maxCol-data[di].count))
				}
				for j in celledLoc.col!..<data[di].count {
					data[di][j] = rows[i][j-celledLoc.col!]
				}
			}
			break
		case .clear:
			data.removeAll()
			break
		default:
			break
		}
	}
	private func scheduleUpload () {
		queue.asyncAfter(deadline: .now() + syncInterval, execute: { _ = self.beginUpload() })
	}
	private func beginUpload () -> Promise<Void> {
		self.operationQueue.map(using: { queue -> Promise<Void> in
			self.uploading = true
			if queue.count > 0 {
				return try self.upload(till: queue.count, ops: queue)
						.then(on: self.queue) { index in self.operationQueue.map { $0.removeSubrange(0..<index) } }
						.then(on: self.queue) { self.beginUpload() }
			} else {
				self.uploading = false
				self.scheduleUpload()
				return .init(())
			}
		})
	}
	private func upload (till index: Int, ops: [SheetOperation]) throws -> Promise<Int> {
		switch ops.first! {
		case .load:
			delegate.uploadWillBegin([.load])
			let promise: Promise<Spreadsheet<Auth>>
			if let sp = spreadsheet {
				promise = .init(sp)
			} else {
				promise = try Spreadsheet<Auth>.get(spreadsheetId, using: authenticator)
							.then(on: queue) { self.spreadsheet = $0 }
			}
			return promise
				.then(on: queue) { sp in
					sp.sheet(forTitle: self.sheetTitle) != nil
					? .init (())
					: try sp.create(title: self.sheetTitle, dimensions: nil).then (on: self.queue) { _ in }
				}
				.then(on: queue) { self.sheetId = self.spreadsheet.sheet(forTitle: self.sheetTitle)!.properties.sheetId }
				.then(on: queue) { try self.spreadsheet.read(sheet: self.sheetTitle) }
				.then(on: queue) { sheet -> Void in
					self.data = sheet.values ?? .init ()
					self.end = sheet.end
					self.isSheetLoaded = true
					self.delegate.uploadDidSucceed([.load])
				}
				.then(on: queue) { self.onLoad.fulfill(()) }
				.then(on: queue) { 1 }
				.catch(on: queue) {
					self.delegate.uploadDidFail([.load], error: $0)
					self.scheduleUpload()
					_ = self.operationQueue.use { _ in self.uploading = false }
				}
		default:
			delegate.uploadWillBegin(ops)
			let operations: [Spreadsheet<Auth>.Operation] = ops.map { $0.operation(sheetId: self.sheetId) }
			return try self.spreadsheet.batchUpdate(operations: .init(requests: operations))
				.then(on: queue) { _ in index }
				.catch(on: queue) {
					self.delegate.uploadDidFail(ops, error: $0)
					self.scheduleUpload()
					_ = self.operationQueue.use { _ in self.uploading = false }
				}
		}
	}
}
public enum SheetOperation {
	case load
	case clear
	case set (Sheet.Location, [[String]])
	case delete (Sheet.Dimension, Range<Int>)
	case insert (Sheet.Dimension, Range<Int>)
	case appendRows ([[String]])
	
	func operation <Auth: Authenticator> (sheetId: Int) -> Spreadsheet<Auth>.Operation {
		switch self {
		case .clear:
			return .clear(sheetId: sheetId)
		case .set(let loc, let rows):
			return .updateCells(sheetId: sheetId, rows: rows, start: loc)
		case .delete(let dim, let range):
			return .delete(sheetId: sheetId, range: range, dimension: dim)
		case .insert(let dim, let range):
			return .insert(sheetId: sheetId, range: range, dimension: dim)
		case .appendRows(let rows):
			return .appendCells(sheetId: sheetId, rows: rows)
		default:
			fatalError()
		}
	}
}
public enum OperationError: Error {
	case outOfBounds
}
public protocol AtomicSheetDelegate: class {
	func uploadWillBegin (_ operations: [SheetOperation])
	func uploadDidSucceed (_ operations: [SheetOperation])
	func uploadDidFail (_ operations: [SheetOperation], error: Error)
}
