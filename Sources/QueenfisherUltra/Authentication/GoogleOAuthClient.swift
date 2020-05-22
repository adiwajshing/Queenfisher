//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/21/20.
//

import Foundation
import Promises

let oAuthApiUrl = URL(string: "https://oauth2.googleapis.com/token")!

public class GoogleOAuthClient: Codable, AuthenticationFactory {
	
	public let clientId: String
	public let clientSecret: String
	public let redirectUris: [URL]
	public let authUri: URL
	
	lazy var factoryKeys: [GoogleScope:GoogleAPIKey] = { [:] } ()
	
	lazy var apiKeys = { [GoogleScope:Promise<GoogleAPIKey>]() }()
	lazy var queue: DispatchQueue = { .init(label: "", attributes: []) }()
	
	func authUrl (for scope: GoogleScope, loginHint: String? = nil) -> URL {
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
	
	func apiKey (from code: String) throws -> Promise<GoogleAPIKey> {		
		let req: OAuthRequest = .init(code: code,
									  refreshToken: nil,
									  clientId: clientId,
									  clientSecret: clientSecret,
									  redirectUri: redirectUris.first!,
									  grantType: .authorizationCode)
		return try oAuthApiUrl.httpRequest(headers: [:], body: req, errorType: GoogleAuthenticationError.self)
			.then(on: queue) { (k: GoogleAPIKey) -> GoogleAPIKey in
				let key = k.with(expiry: Date().addingTimeInterval(k.expiresIn.timeIntervalSince1970))
				self.factoryKeys[key.scope] = key
				self.apiKeys[key.scope] = .init(key)
				return key
			}
	}
	
	func getKey(scope: GoogleScope) throws -> Promise<GoogleAPIKey> {
		guard let factoryKeyToken = self.factoryKeys[scope]?.refreshToken else {
			throw GoogleAuthenticationError.init(error: "refresh token key absent")
		}
		
		let req: OAuthRequest = .init(code: nil,
									  refreshToken: factoryKeyToken,
									  clientId: clientId,
									  clientSecret: clientSecret,
									  redirectUri: redirectUris.first!,
									  grantType: .refreshToken)
		return try oAuthApiUrl.httpRequest(headers: [:], body: req, errorType: GoogleAuthenticationError.self)
	}
	func setFactoryKey (_ key: GoogleAPIKey) throws {
		guard let _ = key.refreshToken else {
			throw GoogleAuthenticationError.init(error: "refresh token required for factory key")
		}
		queue.sync { factoryKeys[key.scope] = key }
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
