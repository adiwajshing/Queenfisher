//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/21/20.
//

import Foundation
import NIO
import AsyncHTTPClient

let oAuthApiUrl = URL(string: "https://oauth2.googleapis.com/token")!

public struct GoogleOAuthClient: Codable, AccessTokenFactory {
	
	public let clientId: String
	public let clientSecret: String
	public let redirectUris: [URL]
	public let authUri: URL
	
	private var factoryToken: AccessToken?
	
	public func authUrl (for scope: GoogleScope, loginHint: String? = nil) -> URL {
		var comps = URLComponents(url: authUri, resolvingAgainstBaseURL: false)!
		var query: [URLQueryItem] = []
		query.append(.init(name: "client_id", value: clientId))
		query.append(.init(name: "scope", value: scope.rawValue))
		query.append(.init(name: "access_type", value: AccessType.offline.rawValue))
		query.append(.init(name: "response_type", value: ResponseType.code.rawValue))
		query.append(.init(name: "redirect_uri", value: redirectUris.first!.absoluteString))
		if let hint = loginHint {
			query.append(.init(name: "login_hint", value: hint))
		}
		comps.queryItems = query
		return comps.url!
	}
	public func fetchToken (fromCode code: String, client: HTTPClient) -> EventLoopFuture<AccessToken> {
		let req: OAuthRequest = .init(code: code,
									  refreshToken: nil,
									  clientId: clientId,
									  clientSecret: clientSecret,
									  redirectUri: redirectUris.first!,
									  grantType: .authorizationCode)
		return client.eventLoopGroup.next()
			.submit { try client.execute(url: oAuthApiUrl,
										 headers: [],
										 body: req,
										 method: .POST,
										 errorType: GoogleAuthenticationError.self) }
			.flatMap { $0 }
			.map { (k:AccessToken) in k.with(expiry: Date().addingTimeInterval(k.expiresIn.timeIntervalSince1970)) }
	}
	public func fetchToken(for scope: GoogleScope, client: HTTPClient) -> EventLoopFuture<AccessToken> {
		client.eventLoopGroup.next()
		.submit { () in
			guard let factoryKeyToken = self.factoryToken?.refreshToken else {
				throw GoogleAuthenticationError.init(error: "refresh token absent")
			}
			let req: OAuthRequest = .init(code: nil,
										  refreshToken: factoryKeyToken,
										  clientId: self.clientId,
										  clientSecret: self.clientSecret,
										  redirectUri: self.redirectUris.first!,
										  grantType: .refreshToken)
			return try client.execute(url: oAuthApiUrl,
									  headers: [],
									  body: req,
									  method: .POST,
									  errorType: GoogleAuthenticationError.self)
		}
		.flatMap { $0 }
	}
	public func factory(usingAccessToken token: AccessToken) throws -> AuthenticationFactory {
		guard let _ = token.refreshToken else {
			throw GoogleAuthenticationError(error: "refresh token absent")
		}
		var oauth = self
		oauth.factoryToken = token
		return .init(scope: token.scope, using: oauth)
	}
	
	struct OAuthRequest: Codable {
		let code: String?
		let refreshToken: String?
		let clientId: String
		let clientSecret: String
		let redirectUri: URL
		let grantType: GrantType
	}
	public enum GrantType: String, Codable {
		case authorizationCode = "authorization_code"
		case refreshToken = "refresh_token"
	}
	public enum ResponseType: String, Codable {
		case code = "code"
	}
	public enum AccessType: String, Codable {
		case offline = "offline"
		case online = "online"
	}
}
