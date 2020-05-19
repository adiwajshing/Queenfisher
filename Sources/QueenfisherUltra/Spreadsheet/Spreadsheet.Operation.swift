//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/11/20.
//

import Foundation

public extension Sheet {
	
	struct Operation: Codable {
		
		public struct Data: Codable {
			public struct Range: Codable {
				let sheetId: Int
				let dimension: Sheet.Dimension?
				let length: Int?
				
				let startIndex: Int?
				let endIndex: Int?
			}
			var range: Range
			var fields: String? = nil
		}
		public struct AddSheetRequest: Codable {
			let properties: Sheet.Properties?
		}
		public struct AppendCellsRequest: Codable {
			let sheetId: Int
			let rows: [RowData]
			let fields: String
		}
		public struct UpdateCellsRequest: Codable {
			public struct GridCoordinate: Codable {
				let sheetId: Int
				let rowIndex: Int?
				let columnIndex: Int?
			}
			
			let rows: [RowData]?
			let fields: String
			let start: GridCoordinate?
			let range: Data.Range?
		}
		public struct MoveCellsRequest: Codable {
			public struct Source: Codable {
				let sheetId: Int
				let dimension: Sheet.Dimension
				let startIndex: Int
				let endIndex: Int
			}
			let source: Source
			let destinationIndex: Int
		}
		
		public var load: Bool? = nil
		var deleteDimension: Data? = nil
		var appendDimension: Data.Range? = nil
		var insertDimension: Data? = nil
		var deleteSheet: Data.Range? = nil
		var moveDimension: MoveCellsRequest? = nil
		var addSheet: AddSheetRequest? = nil
		var updateCells: UpdateCellsRequest? = nil
		var appendCells: AppendCellsRequest? = nil
	}
	struct Operations: Codable {
		let requests: [Operation]
		public init (requests: [Operation]) { self.requests = requests }
		public init (_ op: Operation) { requests = [op] }
	}
	
	struct UpdateResponse: Codable {
		let spreadsheetId: String
		let replies: [Operation]
	}
	
}
public extension Sheet.Operation {
	
	internal static func load () -> Sheet.Operation {
		.init(load: true)
	}
	
	static func updateCells (sheetId: Int, rows: [[String]], start: Sheet.Location) -> Sheet.Operation {
		.init(updateCells: .init(rows: .init(from: rows),
								 fields: "userEnteredValue",
								 start: .init(sheetId: sheetId,
											  rowIndex: start.row,
											  columnIndex: start.col),
								 range: nil))
	}
	static func clear (sheetId: Int) -> Sheet.Operation {
		.init(updateCells: .init(rows: nil, fields: "userEnteredValue",
								 start: nil,
								 range: .init(sheetId: sheetId,
											  dimension: nil,
											  length: nil,
											  startIndex: nil,
											  endIndex: nil)))
	}
	static func appendCells (sheetId: Int, rows: [[String]]) -> Sheet.Operation {
		.init(appendCells: .init(sheetId: sheetId,
								 rows: .init(from: rows),
								 fields: "userEnteredValue"))
	}
	static func insert (sheetId: Int, range: Range<Int>, dimension: Sheet.Dimension) -> Sheet.Operation {
		.init(insertDimension: .init(range: .init(sheetId: sheetId,
												  dimension: dimension,
												  length: nil,
												  startIndex: range.lowerBound,
												  endIndex: range.upperBound)))
	}
	static func delete (sheetId: Int, range: Range<Int>, dimension: Sheet.Dimension) -> Sheet.Operation {
		.init(deleteDimension: .init(range: .init(sheetId: sheetId,
												  dimension: dimension,
												  length: nil,
												  startIndex: range.lowerBound,
												  endIndex: range.upperBound)))
	}
	static func move (sheetId: Int, range: Range<Int>, to dest: Int, dimension: Sheet.Dimension) -> Sheet.Operation {
		.init(moveDimension: .init(source: .init(sheetId: sheetId,
												  dimension: dimension,
												  startIndex: range.lowerBound,
												  endIndex: range.upperBound),
								   destinationIndex: dest))
	}
	static func append (sheetId: Int, size: Int, dimension: Sheet.Dimension) -> Sheet.Operation {
		.init(appendDimension: .init(sheetId: sheetId,
									 dimension: dimension,
									 length: size,
									 startIndex: nil,
									 endIndex: nil))
	}
	static func deleteSheet (sheetId: Int) -> Sheet.Operation {
		.init(deleteSheet: .init(sheetId: sheetId,
								 dimension: nil,
								 length: nil,
								 startIndex: nil,
								 endIndex: nil))
	}
	static func addSheet (title: String, grid: Sheet.Properties.Grid?) -> Sheet.Operation {
		.init(addSheet: .init(properties: .init(title: title, gridProperties: grid)))
	}
	
}
public extension Array where Element == Sheet.RowData {
	init(from rows: [[String]]) {
		self = rows.map { .init(values: $0.map { .init(userEnteredValue: .init(stringValue: $0) ) }) }
	}
}
