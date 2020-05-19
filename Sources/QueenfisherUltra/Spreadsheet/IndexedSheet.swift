//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/19/20.
//

import Foundation
import Promises

public class IndexedSheet <A: Authenticator, K: Comparable & Hashable>: AtomicSheet<A> {
	
	let indexer: (([String]) -> K)
	let header: [String]
	
	public init (spreadsheetId: String, sheetTitle: String,
				 using authenticator: Auth, header: [String],
				 indexer: @escaping (([String]) -> K), delegate: AtomicSheetDelegate? = nil) {
		self.indexer = indexer
		self.header = header
		super.init(spreadsheetId: spreadsheetId, sheetTitle: sheetTitle, using: authenticator, delegate: delegate)
	}
	public func synchronize (with rows: [[String]]) -> Promise<Int> {
		for i in 1..<rows.count {
			if indexer (rows[i]) < indexer (rows[i-1]) {
				return .init(IndexingError.keysUnordered(rows[i], rows[i-1]))
			}
			if rows[i].count != header.count {
				return .init(IndexingError.invalidSizeOfRow(rows[i]))
			}
		}
		var resolutions = 0
		return super.operate {
			// if there is no data uploaded, just upload the entire DB
			if $0.data.count <= 1 {
				try $0.clear()
				try $0.append(rows: [self.header] + rows)
				resolutions = -1
			} else {
				var map = [K:Int]() // store indexes with the number of times they appear
				for row in $0.data.suffix(from: 1) { // exclude the header at index 0
					let id = self.indexer(row)
					map[id] = (map[id] ?? 0)+1
				}
				var placements = [[String]]()
				for row in rows {
					let index = self.indexer(row)
					if map[index] == nil {
						placements.append(row)
					} else {
						map[index]! -= 1
					}
				}
				// delete all rows that should not be there
				for (index, count) in map where count > 0 {
					for _ in 0..<count {
						try self.deleteUnsafe(rowWithKey: index, binarySearch: false)
						resolutions += 1
					}
				}
				// place all rows that were not in the database
				for row in placements {
					resolutions += 1
					try self.placeUnsafe(row: row, binarySearch: true)
				}
			}
		}
		.then(on: queue) { resolutions }
	}
	public func place (row: [String], binarySearch: Bool=true) -> Promise<Void> {
		super.operate { _ in try self.placeUnsafe(row: row, binarySearch: binarySearch) }
	}
	func placeUnsafe (row: [String], binarySearch: Bool) throws {
		if data.count < 1 {
			try append(rows: [self.header, row])
		} else {
			let actual = data.suffix(from: 1)
			let obj = self.indexer(row)
			let index: ArraySlice<[String]>.Index
			if binarySearch {
				index = actual.binarySearch(comparing: self.indexer, with: obj)
			} else {
				index = actual.firstIndex(where: { self.indexer($0)>=obj }) ?? -1
			}
			if actual.indices.contains(index) {
				if self.indexer(actual[index]) > obj {
					try insert(dimension: .rows, range: index..<(index+1))
				}
				try set(rows: [row], at: .row(index))
			} else {
				try append(rows: [row])
			}
		}
	}
	public func delete (row: [String], binarySearch: Bool=true) -> Promise<Void> {
		delete(rowWithKey: indexer(row), binarySearch: binarySearch)
	}
	public func delete (rowWithKey key: K, binarySearch: Bool=true) -> Promise<Void> {
		super.operate { _ in try self.deleteUnsafe(rowWithKey: key, binarySearch: binarySearch) }
	}
	func deleteUnsafe (rowWithKey key: K, binarySearch: Bool) throws {
		if data.count > 1 {
			let actual = data.suffix(from: 1)
			let index: ArraySlice<[String]>.Index
			if binarySearch {
				index = actual.binarySearch(comparing: self.indexer, with: key)
			} else {
				index = actual.firstIndex(where: { self.indexer($0)==key }) ?? -1
			}
			if actual.indices.contains(index), self.indexer(actual[index]) == key {
				try delete(dimension: .rows, range: index..<(index+1))
			} else {
				throw IndexingError.keyNotFound(key)
			}
		}
	}
	public enum IndexingError: Error {
		case keyNotFound (K)
		case keysUnordered ([String], [String])
		case invalidSizeOfRow ([String])
	}
	
}

