//
//  AuthenticationFactory.swift
//  
//
//  Created by Adhiraj Singh on 5/21/20.
//

import Foundation
import NIO
import AsyncHTTPClient

public protocol AccessTokenFactory {
	/// Fetches a fresh access token from Google
	func fetchToken (for scope: GoogleScope, client: HTTPClient) -> EventLoopFuture<AccessToken>
}

public class AuthenticationFactory: Authenticator {
	public let scope: GoogleScope
	public let tokenFactory: AccessTokenFactory
	
	var token: EventLoopFuture<AccessToken>?
	let queue: DispatchQueue = .init(label: "serial-auth-factory", attributes: [])
	
	public init (scope: GoogleScope, using factory: AccessTokenFactory) {
		self.scope = scope
		self.tokenFactory = factory
	}
	
	func fetchToken (client: HTTPClient) -> EventLoopFuture<AccessToken> {
		print("Renewing API key for \(self.scope)...")
		return tokenFactory.fetchToken(for: self.scope, client: client)
			.map { $0.with(expiry: Date().addingTimeInterval($0.expiresIn.timeIntervalSince1970)) }
			.flatMapErrorThrowing({ [weak self] (error) -> AccessToken in
				self?.token = nil
				throw error
			})
	}
	public func authenticate(scope: GoogleScope, client: HTTPClient) -> EventLoopFuture<AccessToken> {
		let ev = client.eventLoopGroup.next()
		return ev.submit { () throws -> EventLoopFuture<AccessToken> in
			if !self.scope.containsAny(scope) {
				throw GoogleAuthenticationError(error: "Cannot authenticate for given scope")
			}
			
			if self.token == nil {
				self.token = self.fetchToken(client: client)
			}
			return self.token!
		}
		.flatMap { $0 }
		.flatMap { [weak self] key -> EventLoopFuture<AccessToken> in
			if let self = self, key.isExpired {
				self.token = self.fetchToken(client: client)
				return self.token!
			} else {
				return ev.makeSucceededFuture(key)
			}
		}
	}
}
