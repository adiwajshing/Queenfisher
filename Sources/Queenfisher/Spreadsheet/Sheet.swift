//
//  Sheet.swift
//  
//
//  Created by Adhiraj Singh on 5/11/20.
//

import Foundation

/// A single sheet in a Google Spreadsheet
public struct Sheet: Codable {
	
	let properties: Properties
	let data: [Sheet.Data]?
	
	
	enum SheetType: String, Codable {
		case unspecified = "SHEET_TYPE_UNSPECIFIED"
		case grid = "GRID"
		case object = "OBJECT"
	}
	
	public struct Properties: Codable {
		public struct Grid: Codable {
			let rowCount: Int
			let columnCount: Int
			var frozenRowCount: Int? = nil
			var frozenColumnCount: Int? = nil
		}
		let title: String
		
		var sheetId: Int? = nil
		var index: Int? = nil
		
		var sheetType: SheetType? = nil
		var hidden: Bool? = nil
		var rightToLeft: Bool? = nil
		var gridProperties: Grid? = nil
	}
	
	public enum Dimension: String, Codable {
		case rows = "ROWS"
		case columns = "COLUMNS"
	}
	public class ValuesRange: Codable {
		let majorDimension: Dimension
		let range: String
		
		public let values: [[String]]?
		
		public lazy var sheet: String = { range.components(separatedBy: "!")[0] }()
		public lazy var start: Sheet.Location = {
			let st = range.components(separatedBy: "!")[1].components(separatedBy: ":")
			return Location (st[0])!
		}()
		public lazy var end: Sheet.Location = {
			let st = range.components(separatedBy: "!")[1].components(separatedBy: ":")
			return Location (st[1])!
		}()
		
		init (dimension: Dimension, range: String, values: [[String]]) {
			self.majorDimension = dimension
			self.range = range
			self.values = values
		}
	}
	public struct CellData: Codable {
		public struct ExtendedValue: Codable {
			var stringValue: String? = nil
			var numberValue: Double? = nil
		}
		var userEnteredValue: ExtendedValue? = nil
		
		func toString () -> String {
			if let value = userEnteredValue?.stringValue {
				return value
			} else if let value = userEnteredValue?.numberValue {
				return String(value)
			}
			return ""
		}
	}
	public struct RowData: Codable {
		let values: [CellData]
	}
	public struct Data: Codable {
		let rowData: [RowData]?
	}
}
