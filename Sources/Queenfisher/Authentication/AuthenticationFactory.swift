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
		let promise = ev.makePromise(of: AccessToken.self)
		queue.async { [weak self] in
			guard let self = self else {
				promise.fail(NSError ())
				return
			}
			if !self.scope.containsAny(scope) {
				promise.fail( GoogleAuthenticationError(error: "Cannot authenticate for given scope") )
				return
			}
			if self.token == nil {
				self.token = self.fetchToken(client: client)
			}
			let future = self.token!
			.flatMap { [weak self] key -> EventLoopFuture<AccessToken> in
				if let self = self, key.isExpired {
					self.token = self.fetchToken(client: client)
					return self.token!
				} else {
					return ev.makeSucceededFuture(key)
				}
			}
			future.whenSuccess(promise.succeed)
			future.whenFailure(promise.fail)
		}
		return promise.futureResult
	}
}
