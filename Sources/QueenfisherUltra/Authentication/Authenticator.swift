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
		try authenticate(scope: .sheets)
			.then (on: .global()) { ["authorization": "\($0.tokenType) \($0.accessToken)"] }
	}
}
public struct GoogleAPIKey: Codable, Authenticator {
	public let accessToken: String
	/// HTTP token type: bearer, basic etc.
	public let tokenType: String
	/// Date after which the token will be invalid
	internal(set) public var expiresIn: Date
	/// Check if the API Key has expired
	public var isExpired: Bool { Date ().timeIntervalSince(expiresIn) < 0 }
	
	public func authenticate(scope: GoogleScope) throws -> Promise<GoogleAPIKey> {
		if isExpired {
			throw GoogleAuthenticationError.init(error: "token expired")
		} else {
			return .init(self)
		}
	}
}
struct GoogleAuthenticationError: Error, Codable {
	let error: String
}
/// Google scopes to authenticate for
public enum GoogleScope: String, Codable {
	case sheets = "https://www.googleapis.com/auth/spreadsheets"
	case devStorageReadOnly = "https://www.googleapis.com/auth/devstorage.read_only"
	case sendMail = "https://www.googleapis.com/auth/gmail.send"
	case calender = "https://www.googleapis.com/auth/calendar"
}
