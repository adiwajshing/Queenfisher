//
//  Authenticator.swift
//  
//
//  Created by Adhiraj Singh on 5/10/20.
//

import Foundation
import Promises
import SwiftJWT

/// Abstract protocol that offers a way to provide a AccessToken
public protocol Authenticator {
	/**
	Authenticate & return an API key.
	For example, to authenticate for spreadsheet access, call ``` authenticate (scope: .sheets) ```
	
	- Parameter scope: the authentication scope for which you require an authentication key
	- Returns: a valid API key for the requested scope
	*/
	func authenticate (scope: GoogleScope) -> Promise<AccessToken>
}
public extension Authenticator {
	/// Authenticate & return the authorization headers required to make an HTTP request
	func authenticationHeaders (scope: GoogleScope) -> Promise<[String:String]> {
		authenticate(scope: scope)
		.then (on: .global()) { ["authorization": "\($0.tokenType) \($0.accessToken)"] }
	}
}
struct GoogleAuthenticationError: Error, Codable {
	let error: String
}

public extension Decodable {
	
	static func loading (fromJSONAt url: URL) throws -> Self {
		let data = try Data (contentsOf: url)
		let decoder = JSONDecoder ()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		let obj = try decoder.decode(Self.self, from: data)
		return obj
	}
	
}
