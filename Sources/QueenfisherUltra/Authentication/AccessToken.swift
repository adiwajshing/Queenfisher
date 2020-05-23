//
//  AccessToken.swift
//  
//
//  Created by Adhiraj Singh on 5/21/20.
//

import Foundation
import Promises

public struct AccessToken: Codable, Authenticator {
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
	
	public func authenticate(scope: GoogleScope) throws -> Promise<AccessToken> {
		if isExpired {
			throw GoogleAuthenticationError(error: "token expired")
		} else if !self.scope.contains(scope) {
			throw GoogleAuthenticationError(error: "invalid scope")
		} else {
			return .init(self)
		}
	}
	func with (expiry date: Date) -> AccessToken {
		.init(accessToken: accessToken,
			  tokenType: tokenType,
			  scope: scope,
			  refreshToken: refreshToken,
			  expiresIn: date)
	}
}
