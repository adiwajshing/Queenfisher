//
//  AuthenticationFactory.swift
//  
//
//  Created by Adhiraj Singh on 5/21/20.
//

import Foundation
import Promises

public protocol AccessTokenFactory {
	/// Fetches a fresh access token from Google
	func fetchToken (for scope: GoogleScope) throws -> Promise<AccessToken>
}

public class AuthenticationFactory: Authenticator {
	public let scope: GoogleScope
	public let tokenFactory: AccessTokenFactory
	
	var promise: Promise<AccessToken>?
	let queue: DispatchQueue = .init(label: "serial-auth-factory", attributes: [])
	
	public init (scope: GoogleScope, using factory: AccessTokenFactory) {
		self.scope = scope
		self.tokenFactory = factory
	}
	
	func fetchToken () throws -> Promise<AccessToken> {
		print("Renewing API key for \(self.scope)...")
		return try tokenFactory.fetchToken(for: self.scope)
			.then(on: self.queue) { $0.with(expiry: Date().addingTimeInterval($0.expiresIn.timeIntervalSince1970)) }
			.catch(on: self.queue) { _ in self.promise = nil }
	}
	
	public func authenticate (scope: GoogleScope) throws -> Promise<AccessToken> {
		if !self.scope.containsAny(scope) {
			throw GoogleAuthenticationError(error: "Cannot authenticate for given scope")
		}
		
		return Promise(())
		.then(on: queue) { _ -> Promise<AccessToken> in
			if self.promise == nil {
				self.promise = try self.fetchToken()
			}
			return self.promise!
		}
		.then(on: queue) { key -> Promise<AccessToken> in
			if key.isExpired {
				self.promise = try self.fetchToken()
				return self.promise!
			} else {
				return .init(key)
			}
		}
	}
}
