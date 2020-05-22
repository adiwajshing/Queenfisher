//
//  Authenticator.swift
//  
//
//  Created by Adhiraj Singh on 5/10/20.
//

import Foundation
import Promises
import SwiftJWT

/// Abstract protocol that offers a way to provide a GoogleAPIKey
public protocol Authenticator: Codable {
	/**
	Authenticate & return an API key.
	For example, to authenticate for spreadsheet access, call ``` authenticate (scope: .sheets) ```
	
	- Parameter scope: the authentication scope for which you require an authentication key
	- Returns: a valid API key for the requested scope
	*/
	func authenticate (scope: GoogleScope) throws -> Promise<GoogleAPIKey>
}
public extension Authenticator {
	/// Authenticate & return the authorization headers required to make an HTTP request
	func authenticationHeaders (scope: GoogleScope) throws -> Promise<[String:String]> {
		try authenticate(scope: scope)
			.then (on: .global()) { ["authorization": "\($0.tokenType) \($0.accessToken)"] }
	}
}
struct GoogleAuthenticationError: Error, Codable {
	let error: String
}
/// Google scopes to authenticate for
public enum GoogleScope: String, Codable {
	case sheets = "https://www.googleapis.com/auth/spreadsheets"
	case devStorageReadOnly = "https://www.googleapis.com/auth/devstorage.read_only"
	case mailSend = "https://www.googleapis.com/auth/gmail.send"
	case mailRead = "https://www.googleapis.com/auth/gmail.readonly"
	case mailFullAccess = "https://mail.google.com/"
	case calender = "https://www.googleapis.com/auth/calendar"
	case profile = "https://www.googleapis.com/auth/userinfo.profile"
}

extension Decodable {
	
	static func loading (fromJSONAt url: URL) throws -> Self {
		let data = try Data (contentsOf: url)
		let decoder = JSONDecoder ()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		let obj = try decoder.decode(Self.self, from: data)
		return obj
	}
	
}
