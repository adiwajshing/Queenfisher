//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/16/20.
//

import Foundation
import SwiftJWT
import Promises
import Atomics

/// Google Service Account to use for authentication. See https://developers.google.com/identity/protocols/oauth2/service-account
public class GoogleServiceAccount: Codable, Authenticator {
	/// The JWT Claim
	struct Claim: Claims {
		let iss: String
		let aud: URL
		let exp: Date
		let iat: Date
		let scope: GoogleScope
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
	
	
	lazy var apiKeys = { [GoogleScope:Promise<GoogleAPIKey>]() }()
	lazy var queue: DispatchQueue = { .init(label: "", attributes: []) }()
	
	/// Load a service account from a JSON stored in a file. This file is usually the one downloaded after you create a service account
	public static func loading (fromJSONAt url: URL) throws -> GoogleServiceAccount {
		let data = try Data (contentsOf: url)
		let decoder = JSONDecoder ()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		let obj = try decoder.decode(GoogleServiceAccount.self, from: data)
		obj.queue.sync { }
		return obj
	}
	
	public func authenticate (scope: GoogleScope) throws -> Promise<GoogleAPIKey> {
		Promise(())
		.then(on: queue) { _ -> Promise<GoogleAPIKey> in
			if let p = self.apiKeys[scope] {
				return p
			} else {
				let p = try self.getKey(scope: scope)
				self.apiKeys[scope] = p
				return p
			}
		}
		.then(on: queue) { key -> Promise<GoogleAPIKey> in
			if key.isExpired {
				let p = try self.getKey(scope: scope)
				self.apiKeys[scope] = p
				return p
			} else {
				return .init(key)
			}
		}
	}
	func getKey (scope: GoogleScope) throws -> Promise<GoogleAPIKey> {
		print("Renewing API key...")
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
			.then(on: queue) { (key: GoogleAPIKey) -> GoogleAPIKey in
				var k = key
				k.expiresIn = Date().addingTimeInterval(key.expiresIn.timeIntervalSince1970)
				return k
			}
			.catch(on: queue) { _ in self.apiKeys[scope] = nil }
	}
}
