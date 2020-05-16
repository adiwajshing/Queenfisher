//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/11/20.
//

import Foundation

public extension Spreadsheet {
	
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
		public struct AddData: Codable {
			public struct Properties: Codable {
				let title: String
				let sheetId: Int?
				let gridProperties: Sheet.Properties.Grid?
			}
			let properties: Properties
		}
		
		public struct CellData: Codable {
			public struct ExtendedValue: Codable {
				let stringValue: String
			}
			let userEnteredValue: ExtendedValue
		}
		public struct RowData: Codable {
			let values: [CellData]
			
			static func from (rows: [[String]]) -> [RowData] {
				rows.map { .init(values: $0.map { .init(userEnteredValue: .init(stringValue: $0) ) }) }
			}
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
		
		var deleteDimension: Data? = nil
		var appendDimension: Data.Range? = nil
		var insertDimension: Data? = nil
		var moveDimension: Data? = nil
		var deleteSheet: Data.Range? = nil
		var addSheet: AddData? = nil
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
public extension Spreadsheet.Operation {
	
	static func updateCells (sheetId: Int, rows: [[String]], start: Sheet.Location) -> Spreadsheet.Operation {
		.init(updateCells: .init(rows: RowData.from(rows: rows),
								 fields: "userEnteredValue",
								 start: .init(sheetId: sheetId,
											  rowIndex: start.row,
											  columnIndex: start.col),
								 range: nil))
	}
	static func clear (sheetId: Int) -> Spreadsheet.Operation {
		.init(updateCells: .init(rows: nil, fields: "userEnteredValue",
								 start: nil,
								 range: .init(sheetId: sheetId,
											  dimension: nil,
											  length: nil,
											  startIndex: nil,
											  endIndex: nil)))
	}
	static func appendCells (sheetId: Int, rows: [[String]]) -> Spreadsheet.Operation {
		.init(appendCells: .init(sheetId: sheetId,
								 rows: RowData.from(rows: rows),
								 fields: "userEnteredValue"))
	}
	static func insert (sheetId: Int, range: Range<Int>, dimension: Sheet.Dimension) -> Spreadsheet.Operation {
		.init(insertDimension: .init(range: .init(sheetId: sheetId,
												  dimension: dimension,
												  length: nil,
												  startIndex: range.lowerBound,
												  endIndex: range.upperBound)))
	}
	static func delete (sheetId: Int, range: Range<Int>, dimension: Sheet.Dimension) -> Spreadsheet.Operation {
		.init(deleteDimension: .init(range: .init(sheetId: sheetId,
												  dimension: dimension,
												  length: nil,
												  startIndex: range.lowerBound,
												  endIndex: range.upperBound)))
	}
	static func append (sheetId: Int, size: Int, dimension: Sheet.Dimension) -> Spreadsheet.Operation {
		.init(appendDimension: .init(sheetId: sheetId,
									 dimension: dimension,
									 length: size,
									 startIndex: nil,
									 endIndex: nil))
	}
	static func deleteSheet (sheetId: Int) -> Spreadsheet.Operation {
		.init(deleteSheet: .init(sheetId: sheetId,
								 dimension: nil,
								 length: nil,
								 startIndex: nil,
								 endIndex: nil))
	}
	static func addSheet (title: String, grid: Sheet.Properties.Grid?) -> Spreadsheet.Operation {
		.init(addSheet: .init(properties: .init(title: title, sheetId: nil, gridProperties: grid)))
	}
	
}
