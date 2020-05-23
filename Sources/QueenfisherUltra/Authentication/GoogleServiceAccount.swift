//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/16/20.
//

import Foundation
import SwiftJWT
import Promises

/// Google Service Account to use for authentication. See https://developers.google.com/identity/protocols/oauth2/service-account
public class GoogleServiceAccount: Codable, AccessTokenFactory {
	/// The JWT Claim
	struct Claim: Claims {
		let iss: String
		let aud: URL
		let exp: Date
		let iat: Date
		let scope: GoogleScope
	}
	/// Access token returned for service accounts
	struct SAToken: Decodable {
		let accessToken: String
		let expiresIn: Double
		let tokenType: String
	}
	/// account type, ("service_account" in this class)
	public let type: String
	/// private key identifier
	public let privateKeyId: String
	/// private key data in a .pem format
	public let privateKey: String
	/// email of the service account
	public let clientEmail: String
	public let clientId: String
	public let clientX509CertUrl: URL
	/// URL to request authentication from
	public let tokenUri: URL
	
	public func factory (for scope: GoogleScope) -> AuthenticationFactory {
		.init(scope: scope, using: self)
	}
	public func fetchToken (for scope: GoogleScope) throws -> Promise<AccessToken> {
		/*
			Structure of JWT & Claims from https://developers.google.com/identity/protocols/oauth2/service-account#authorizingrequests
		*/
		let claim = Claim (iss: clientEmail,
						   aud: tokenUri,
						   exp: Date (timeIntervalSinceNow: 60*60), // expire access token in 60 minutes
						   iat: Date (),
						   scope: scope)
		var jwt = JWT (header: .init (typ: "JWT"), claims: claim) // generate a JWT token
		let signer = JWTSigner.rs256(privateKey: privateKey.data(using: .utf8)!) // signer using RS256, and our private key
		let signed = try jwt.sign(using: signer) // sign the token
		
		let body = ["grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", // Google requires this
					"assertion": signed]
		return try tokenUri.httpRequest(headers: [:], body: body, errorType: GoogleAuthenticationError.self)
			.then(on: .global()) { (k: SAToken) -> AccessToken in
				AccessToken(accessToken: k.accessToken,
							tokenType: k.tokenType,
							scope: scope,
							refreshToken: nil,
							expiresIn: Date().addingTimeInterval(k.expiresIn))
			}
	}
}
