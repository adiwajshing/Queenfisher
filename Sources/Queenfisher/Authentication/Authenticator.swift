//
//  Authenticator.swift
//  
//
//  Created by Adhiraj Singh on 5/10/20.
//

import Foundation
import NIO
import AsyncHTTPClient

/// Abstract protocol that offers a way to provide a AccessToken
public protocol Authenticator {
	/**
	Authenticate & return an API key.
	For example, to authenticate for spreadsheet access, call ``` authenticate (scope: .sheets, client: someHTTPClient) ```
	
	- Parameter scope: the authentication scope for which you require an authentication key
	- Returns: a valid API key for the requested scope
	*/
	func authenticate (scope: GoogleScope, client: HTTPClient) -> EventLoopFuture<AccessToken>
}
public extension Authenticator {
	/// Authenticate & return the authorization header required to make an HTTP request
	func authenticationHeader (scope: GoogleScope, client: HTTPClient) -> EventLoopFuture<(String,String)> {
		authenticate(scope: scope, client: client)
		.map { ("authorization", "\($0.tokenType) \($0.accessToken)") }
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
