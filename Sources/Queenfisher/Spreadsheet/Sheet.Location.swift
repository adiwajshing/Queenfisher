//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/16/20.
//

import Foundation

public extension Sheet {
	
	struct Location: CustomStringConvertible {
			public let col: Int?
			public let row: Int?
			
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
					var col = 0
					if let charsLength = str.firstIndex(where: { $0.isNumber }) {
						var prefix = String(str.prefix(upTo: charsLength))
						
						while prefix.count > 0 {
							let exp = Int(pow(26, Double(prefix.count-1)) as Double)
							col += (Int(prefix.first!.asciiValue!) - 64)*exp
							_ = prefix.removeFirst()
						}
						col -= 1
						let row = Int(str.suffix(from: charsLength))!

						self = .cell(col, row)
					} else {
						return nil
					}
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
}
