//
//  Sheet.swift
//  
//
//  Created by Adhiraj Singh on 5/11/20.
//

import Foundation

/// A single sheet in a Google Spreadsheet
public struct Sheet: Codable {
	
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
		
		let sheetId: Int
		let title: String
		let index: Int
		let sheetType: SheetType
		let hidden: Bool?
		let rightToLeft: Bool?
		
		let gridProperties: Grid
	}
	
	public struct Location: CustomStringConvertible {
		let col: Int?
		let row: Int?
		
		public var description: String {
			var str = ""
			if var rem = col {
				repeat {
					let char = (rem%26) + 65 // number + 'A'
					str.append( Character(.init(UInt8(char))) )
					rem /= 26
				} while rem > 0
			}
			if let row = row {
				str += "\(row+1)"
			}
			return str
		}
		init (col: Int?, row: Int?) {
			self.col = col
			self.row = row
		}
		public init? (_ str: String) {
			if str.count == 1 {
				if str.first!.isNumber {
					self.init(col: 0, row: Int(str)!)
				} else {
					self.init(col: 0, row: Int(str)!)
				}
			} else if str.count > 1 {
				let col = str.first!.asciiValue! - 65
				let row = Int(str.suffix(from: str.index(after: str.startIndex)))!
				self = .cell(Int(col), row)
			} else {
				return nil
			}
		}
		
		public func celled () -> Location { .init(col: col ?? 0, row: row ?? 0) }
		
		public static func cell (_ col: Int, _ row: Int) -> Self { .init(col: col, row: row) }
		public static func column (_ col: Int) -> Self { .init(col: col, row: nil) }
		public static func row (_ row: Int) -> Self { .init(col: nil, row: row) }
		
		public static func + (lhs: Self, rhs: (Int, Int)) -> Self { lhs + .init(col: rhs.0, row: rhs.1) }
		public static func + (lhs: Self, rhs: Self) -> Self {
			var col: Int? = nil
			if lhs.col != nil || rhs.col != nil {
				col = (lhs.col ?? 0) + (rhs.col ?? 0)
			}
			var row: Int? = nil
			if lhs.row != nil || rhs.row != nil {
				row = (lhs.row ?? 0) + (rhs.row ?? 0)
			}
			return .init(col: col, row: row)
		}
	}
	
	public enum Dimension: String, Codable {
		case rows = "ROWS"
		case columns = "COLUMNS"
	}
	public class Data: Codable {
		let majorDimension: Dimension
		let range: String
		
		public let values: [[String]]?
		
		public lazy var sheet: String = { range.components(separatedBy: "!")[0] }()
		public lazy var start: Location = {
			let st = range.components(separatedBy: "!")[1].components(separatedBy: ":")
			return Location (st[0])!
		}()
		public lazy var end: Location = {
			let st = range.components(separatedBy: "!")[1].components(separatedBy: ":")
			return Location (st[1])!
		}()
		
		lazy private var map: [String:Int] = {
			var dict = [String:Int]()
			if let values = values, values.count > 0 {
				for i in 0..<values[0].count {
					dict[values[0][i]] = i
				}
			}
			return dict
		} ()
		
		init (dimension: Dimension, range: String, values: [[String]]) {
			self.majorDimension = dimension
			self.range = range
			self.values = values
		}
		
		public subscript (_ column: String, _ row: Int) -> String? {
			if let values = values, let c = map [column], row+1 < values.count {
				return values[row+1][c]
			}
			return nil
		}
	}
	
	let properties: Properties
}
