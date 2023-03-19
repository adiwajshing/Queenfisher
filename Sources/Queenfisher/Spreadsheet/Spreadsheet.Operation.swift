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
			public let sheetId: Int
			public let dimension: Sheet.Dimension?
			public let length: Int?
			
			public let startIndex: Int?
			public let endIndex: Int?
		}
		public struct GenericRequest: Codable {
			public var range: SheetRange
			public var fields: String? = nil
		}
		public struct AddSheetRequest: Codable {
			public let properties: Sheet.Properties?
		}
		public struct AppendCellsRequest: Codable {
			public let sheetId: Int
			public let rows: [Sheet.RowData]
			public let fields: String
		}
		public struct UpdateCellsRequest: Codable {
			public struct GridCoordinate: Codable {
				public let sheetId: Int
				public let rowIndex: Int?
				public let columnIndex: Int?
			}
			
			public let rows: [Sheet.RowData]?
			public let fields: String
			public let start: GridCoordinate?
			public let range: SheetRange?
		}
		public struct MoveCellsRequest: Codable {
			public struct Source: Codable {
				public let sheetId: Int
				public let dimension: Sheet.Dimension
				public let startIndex: Int
				public let endIndex: Int
			}
			public let source: Source
			public let destinationIndex: Int
		}
		
		public var load: Bool? = nil
		public var deleteDimension: GenericRequest? = nil
		public var appendDimension: SheetRange? = nil
		public var insertDimension: GenericRequest? = nil
		public var deleteSheet: SheetRange? = nil
		public var moveDimension: MoveCellsRequest? = nil
		public var addSheet: AddSheetRequest? = nil
		public var updateCells: UpdateCellsRequest? = nil
		public var appendCells: AppendCellsRequest? = nil
	}
	/// A list of updates to perform on a spreadsheet
	struct Operations: Codable {
		public let requests: [Operation]
		public init (requests: [Operation]) { self.requests = requests }
		public init (_ op: Operation) { requests = [op] }
	}
	/// Response to a BatchUpdate
	struct UpdateResponse: Codable {
		public let spreadsheetId: String
		public let replies: [Operation]
	}
	/// Response to a write request
	struct WriteResponse: Codable {
		public let updatedRange: String
		public let updatedRows: Int
		public let updatedColumns: Int
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
