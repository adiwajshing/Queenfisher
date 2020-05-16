//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/11/20.
//

import Foundation

public extension Spreadsheet {
	
	struct WriteResponse: Codable {
		let updatedRange: String
		let updatedRows: Int
		let updatedColumns: Int
	}
	
	struct Properties: Codable {
		let title: String
	}
	
	struct ErrorResponse: Codable, Error {
		struct Error: Codable {
			let code: Int
			let status: String
			let message: String
		}
		let error: Error
	}

}
