//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/21/20.
//

import Foundation
import Promises

public struct GoogleAPIKey: Codable, Authenticator {
	public var accessToken: String
	/// HTTP token type: bearer, basic etc.
	public let tokenType: String
	/// Scope for which the key is valid
	public let scope: GoogleScope
	/// Refresh token
	public let refreshToken: String?
	/// Date after which the token will be invalid
	internal(set) public var expiresIn: Date
	
	/// Check if the API Key has expired
	public var isExpired: Bool { Date ().timeIntervalSince(expiresIn) > 0 }
	
	public func authenticate(scope: GoogleScope) throws -> Promise<GoogleAPIKey> {
		if isExpired {
			throw GoogleAuthenticationError.init(error: "token expired")
		} else {
			return .init(self)
		}
	}
	func with (expiry date: Date) -> GoogleAPIKey {
		.init(accessToken: accessToken, tokenType: tokenType, scope: scope, refreshToken: refreshToken, expiresIn: date)
	}
}
