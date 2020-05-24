//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/24/20.
//

import Foundation

public struct ErrorResponse: Codable, Error {
	struct SubError: Codable {
		let domain: String
		let reason: String
		let message: String
	}
	struct Error: Codable {
		let code: Int
		let status: String?
		let errors: [SubError]?
		let message: String
	}
	let error: Error
}
