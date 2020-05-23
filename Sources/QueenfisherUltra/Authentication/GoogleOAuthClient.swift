//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/21/20.
//

import Foundation
import Promises

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
	
	public func fetchToken (fromCode code: String) throws -> Promise<AccessToken> {
		let req: OAuthRequest = .init(code: code,
									  refreshToken: nil,
									  clientId: clientId,
									  clientSecret: clientSecret,
									  redirectUri: redirectUris.first!,
									  grantType: .authorizationCode)
		return try oAuthApiUrl.httpRequest(headers: [:], body: req, errorType: GoogleAuthenticationError.self)
			.then(on: .global()) { (k: AccessToken) -> AccessToken in
				k.with(expiry: Date().addingTimeInterval(k.expiresIn.timeIntervalSince1970))
			}
	}
	public func fetchToken(for scope: GoogleScope) throws -> Promise<AccessToken> {
		guard let factoryKeyToken = self.factoryToken?.refreshToken else {
			throw GoogleAuthenticationError.init(error: "refresh token absent")
		}
		
		let req: OAuthRequest = .init(code: nil,
									  refreshToken: factoryKeyToken,
									  clientId: clientId,
									  clientSecret: clientSecret,
									  redirectUri: redirectUris.first!,
									  grantType: .refreshToken)
		return try oAuthApiUrl.httpRequest(headers: [:], body: req, errorType: GoogleAuthenticationError.self)
	}
	public func factory(for scope: GoogleScope, usingAccessToken token: AccessToken) throws -> AuthenticationFactory {
		guard let _ = token.refreshToken else {
			throw GoogleAuthenticationError.init(error: "refresh token absent")
		}
		guard token.scope.contains(scope) else {
			throw GoogleAuthenticationError.init(error: "token does not contain required scopes")
		}
		var client = self
		client.factoryToken = token
		return .init(scope: scope, using: client)
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
