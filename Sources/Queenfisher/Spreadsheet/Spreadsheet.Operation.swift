//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/11/20.
//

import Foundation

public extension Spreadsheet {
	/// A single kind of update to apply to a spreadsheet.
	struct Operation: Codable {
		
		public struct SheetRange: Codable {
			let sheetId: Int
			let dimension: Sheet.Dimension?
			let length: Int?
			
			let startIndex: Int?
			let endIndex: Int?
		}
		public struct GenericRequest: Codable {
			var range: SheetRange
			var fields: String? = nil
		}
		public struct AddSheetRequest: Codable {
			let properties: Sheet.Properties?
		}
		public struct AppendCellsRequest: Codable {
			let sheetId: Int
			let rows: [Sheet.RowData]
			let fields: String
		}
		public struct UpdateCellsRequest: Codable {
			public struct GridCoordinate: Codable {
				let sheetId: Int
				let rowIndex: Int?
				let columnIndex: Int?
			}
			
			let rows: [Sheet.RowData]?
			let fields: String
			let start: GridCoordinate?
			let range: SheetRange?
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
		var deleteDimension: GenericRequest? = nil
		var appendDimension: SheetRange? = nil
		var insertDimension: GenericRequest? = nil
		var deleteSheet: SheetRange? = nil
		var moveDimension: MoveCellsRequest? = nil
		var addSheet: AddSheetRequest? = nil
		var updateCells: UpdateCellsRequest? = nil
		var appendCells: AppendCellsRequest? = nil
	}
	/// A list of updates to perform on a spreadsheet
	struct Operations: Codable {
		let requests: [Operation]
		public init (requests: [Operation]) { self.requests = requests }
		public init (_ op: Operation) { requests = [op] }
	}
	/// Response to a BatchUpdate
	struct UpdateResponse: Codable {
		let spreadsheetId: String
		let replies: [Operation]
	}
	/// Response to a write request
	struct WriteResponse: Codable {
		let updatedRange: String
		let updatedRows: Int
		let updatedColumns: Int
	}
	
}
public extension Spreadsheet.Operation {
	/// Internal function to load spreadsheet, used in `AtomicSheet`
	internal static func load () -> Spreadsheet.Operation {
		.init(load: true)
	}
	/// Updates many cells at once.
	static func updateCells (sheetId: Int, rows: [[String]], start: Sheet.Location) -> Spreadsheet.Operation {
		.init(updateCells: .init(rows: .init(from: rows),
								 fields: "userEnteredValue",
								 start: .init(sheetId: sheetId,
											  rowIndex: start.row,
											  columnIndex: start.col),
								 range: nil))
	}
	/// Clears the sheet.
	static func clear (sheetId: Int) -> Spreadsheet.Operation {
		.init(updateCells: .init(rows: nil, fields: "userEnteredValue",
								 start: nil,
								 range: .init(sheetId: sheetId,
											  dimension: nil,
											  length: nil,
											  startIndex: nil,
											  endIndex: nil)))
	}
	/// Appends cells after the last row with data in a sheet.
	static func appendCells (sheetId: Int, rows: [[String]]) -> Spreadsheet.Operation {
		.init(appendCells: .init(sheetId: sheetId,
								 rows: .init(from: rows),
								 fields: "userEnteredValue"))
	}
	/// Inserts new rows or columns in a sheet.
	static func insert (sheetId: Int, range: Range<Int>, dimension: Sheet.Dimension) -> Spreadsheet.Operation {
		.init(insertDimension: .init(range: .init(sheetId: sheetId,
												  dimension: dimension,
												  length: nil,
												  startIndex: range.lowerBound,
												  endIndex: range.upperBound)))
	}
	/// Deletes rows or columns in a sheet.
	static func delete (sheetId: Int, range: Range<Int>, dimension: Sheet.Dimension) -> Spreadsheet.Operation {
		.init(deleteDimension: .init(range: .init(sheetId: sheetId,
												  dimension: dimension,
												  length: nil,
												  startIndex: range.lowerBound,
												  endIndex: range.upperBound)))
	}
	/// Moves rows or columns to another location in a sheet.
	static func move (sheetId: Int, range: Range<Int>, to dest: Int, dimension: Sheet.Dimension) -> Spreadsheet.Operation {
		.init(moveDimension: .init(source: .init(sheetId: sheetId,
												  dimension: dimension,
												  startIndex: range.lowerBound,
												  endIndex: range.upperBound),
								   destinationIndex: dest))
	}
	/// Appends dimensions to the end of a sheet.
	static func append (sheetId: Int, size: Int, dimension: Sheet.Dimension) -> Spreadsheet.Operation {
		.init(appendDimension: .init(sheetId: sheetId,
									 dimension: dimension,
									 length: size,
									 startIndex: nil,
									 endIndex: nil))
	}
	/// Deletes a sheet.
	static func deleteSheet (sheetId: Int) -> Spreadsheet.Operation {
		.init(deleteSheet: .init(sheetId: sheetId,
								 dimension: nil,
								 length: nil,
								 startIndex: nil,
								 endIndex: nil))
	}
	/// Adds a sheet.
	static func addSheet (title: String, grid: Sheet.Properties.Grid?) -> Spreadsheet.Operation {
		.init(addSheet: .init(properties: .init(title: title, gridProperties: grid)))
	}
}
public extension Array where Element == Sheet.RowData {
	init(from rows: [[String]]) {
		self = rows.map { .init(values: $0.map { .init(userEnteredValue: .init(stringValue: $0) ) }) }
	}
}
