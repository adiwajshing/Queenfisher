//
//  IndexedSheet.swift
//  
//
//  Created by Adhiraj Singh on 5/19/20.
//

import Foundation
import Promises

/// Methods to upload & maintain a keyed database in a Google Sheet in O(log N) time
public class IndexedSheet <K: Comparable & Hashable>: AtomicSheet {
	/// method to generate the key for the given row
	let indexer: (([String]) -> K)
	/// the header row for the DB
	let header: [String]
	
	public init (spreadsheetId: String, sheetTitle: String,
				 using authenticator: Authenticator, header: [String],
				 indexer: @escaping (([String]) -> K), delegate: AtomicSheetDelegate? = nil) {
		self.indexer = indexer
		self.header = header
		super.init(spreadsheetId: spreadsheetId, sheetTitle: sheetTitle, using: authenticator, delegate: delegate)
	}
	
	public func update (values: String..., for key: K, offset: Int, binarySearch: Bool=true) -> Promise<Void> {
		operate {
			let actual = $0.data.suffix(from: 1)
			let index = self.position(for: key, in: actual, binarySearch: binarySearch)
			if actual.indices.contains(index), self.indexer(actual[index])==key {
				try self.set(rows: [ values ], at: .cell(offset, index))
			} else {
				throw IndexingError.keyNotFound(key)
			}
		}
	}
	
	public func place (row: [String], binarySearch: Bool=true) -> Promise<Void> {
		operate { try self.placeUnsafe(s: $0, row: row, binarySearch: binarySearch) }
	}
	func placeUnsafe (s: AtomicSheet, row: [String], binarySearch: Bool) throws {
		if s.data.count < 1 {
			try append(rows: [self.header, row])
		} else {
			let actual = s.data.suffix(from: 1)
			let obj = self.indexer(row)
			let index = self.position(for: obj, in: actual, binarySearch: binarySearch)
			
			if actual.indices.contains(index) {
				if self.indexer(actual[index]) > obj {
					try s.insert(dimension: .rows, range: index..<(index+1))
				}
				try s.set(rows: [row], at: .row(index))
			} else {
				try s.append(rows: [row])
			}
		}
	}
	public func delete (row: [String], binarySearch: Bool=true) -> Promise<Void> {
		delete(rowWithKey: indexer(row), binarySearch: binarySearch)
	}
	public func delete (rowWithKey key: K, binarySearch: Bool=true) -> Promise<Void> {
		operate { _ in try self.deleteUnsafe(rowWithKey: key, binarySearch: binarySearch) }
	}
	func deleteUnsafe (rowWithKey key: K, binarySearch: Bool) throws {
		if data.count > 1 {
			let actual = data.suffix(from: 1)
			let index = self.position(for: key, in: actual, binarySearch: binarySearch)
			if actual.indices.contains(index), self.indexer(actual[index]) == key {
				try delete(dimension: .rows, range: index..<(index+1))
			} else {
				
				throw IndexingError.keyNotFound(key)
			}
		}
	}
	func position (for key: K, in slice: ArraySlice<[String]>, binarySearch: Bool) -> ArraySlice<[String]>.Index {
		let index: ArraySlice<[String]>.Index
		if binarySearch {
			index = slice.binarySearch(comparing: indexer, with: key)
		} else {
			index = slice.firstIndex(where: { indexer($0)>=key }) ?? (slice.endIndex+1)
		}
		return index
	}
	
	public enum IndexingError: Error {
		case keyNotFound (K)
		case keysUnordered ([String], [String])
		case invalidSizeOfRow ([String])
		case duplicateKeys (K)
	}
	
}

public extension IndexedSheet {
	
	func synchronize (with rowFunction: @escaping () -> Promise<[[String]]>) -> Promise<Int> {
		executeInPendingChain {
			rowFunction ()
			.then(on: self.queue) { rows -> Int in
				// verify list is in sorted order
				for i in 1..<rows.count {
					if self.indexer (rows[i]) < self.indexer (rows[i-1]) {
						throw IndexingError.keysUnordered(rows[i], rows[i-1])
					}
					if rows[i].count != self.header.count {
						throw IndexingError.invalidSizeOfRow(rows[i])
					}
				}
				
				var resolutions = 0
				
				// if there is no data uploaded, just upload the entire DB
				if self.data.count <= 1 {
					try self.clear()
					try self.append(rows: [self.header] + rows)
					resolutions = -1
					
				} else {
					if self.data[0] != self.header {
						try self.set(rows: [self.header], at: .row(0))
					}
					
					var map = [K:(Int, [String])]()
					// map out rows
					for i in rows.indices {
						let row = rows[i]
						let id = self.indexer(row)
						if map[id] != nil {
							throw IndexingError.duplicateKeys(id)
						}
						
						map[id] = (0, row)
					}
					// delete orphan & duplicate rows
					var i = 1
					while i < self.data.count {
						let id = self.indexer(self.data[i])
						if map[id] == nil || map[id]!.0 > 0 {
							try self.delete(dimension: .rows, range: i..<(i+1))
							resolutions += 1
						} else {
							map[id]! = (map[id]!.0+1, map[id]!.1)
							i += 1
						}
					}
					if self.data.count > 2 {
						// fix order
						for i in 2..<self.data.count {
							let index = self.indexer (self.data[i])
							if index < self.indexer (self.data[i-1]) {
								let correctIndex = self.position(for: index, in: self.data.suffix(from: 1), binarySearch: false)
								try self.move(dimension: .rows, range: i..<(i+1), to: correctIndex)
								resolutions += 1
							}
						}
					}
					// place all rows not in the sheet
					for (_, value) in map where value.0 == 0 {
						try self.placeUnsafe(s: self, row: value.1, binarySearch: true)
						resolutions += 1
					}
				}
				if !self.uploading {
					self.scheduleUpload(in: self.uploadInterval)
				}
				return resolutions
			}
		}
	}
}
