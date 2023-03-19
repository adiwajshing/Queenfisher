//
//  Sheet.swift
//  
//
//  Created by Adhiraj Singh on 5/11/20.
//

import Foundation

/// A single sheet in a Google Spreadsheet
public struct Sheet: Codable {
	
    public let properties: Properties
    public let data: [Sheet.Data]?
	
    public enum SheetType: String, Codable {
		case unspecified = "SHEET_TYPE_UNSPECIFIED"
		case grid = "GRID"
		case object = "OBJECT"
	}
	
	public struct Properties: Codable {
        
		public struct Grid: Codable {
            public let rowCount: Int
            public let columnCount: Int
            public var frozenRowCount: Int? = nil
            public var frozenColumnCount: Int? = nil
		}
        
        public let title: String
		
        public var sheetId: Int? = nil
        public var index: Int? = nil
		
        public var sheetType: SheetType? = nil
        public var hidden: Bool? = nil
        public var rightToLeft: Bool? = nil
        public var gridProperties: Grid? = nil
	}
	
	public enum Dimension: String, Codable {
		case rows = "ROWS"
		case columns = "COLUMNS"
	}
    
	public class ValuesRange: Codable {
        
        public let majorDimension: Dimension
        public let range: String
		
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
            public var stringValue: String? = nil
            public var numberValue: Double? = nil
		}
        public var userEnteredValue: ExtendedValue? = nil
		
        public func toString () -> String {
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
