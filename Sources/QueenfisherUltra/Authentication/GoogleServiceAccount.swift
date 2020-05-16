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
public class GoogleServiceAccount: Codable, Authenticator {
	/// The JWT Claim
	struct Claim: Claims {
		let iss: String
		let aud: URL
		let exp: Date
		let iat: Date
		let scope: GoogleScope
	}
	/// account type ("service_account" in this class)
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
	
	var apiKey: GoogleAPIKey? = nil
	
	/// Load a service account from a JSON stored in a file. This file is usually the one downloaded after you create a service account
	static func loading (fromJSONAt url: URL) throws -> GoogleServiceAccount {
		let data = try Data (contentsOf: url)
		let decoder = JSONDecoder ()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		return try decoder.decode(GoogleServiceAccount.self, from: data)
	}
	
	public func authenticate (scope: GoogleScope) throws -> Promise<GoogleAPIKey> {
		if let apiKey = apiKey, Date ().timeIntervalSince(apiKey.expiresIn) < 0 {
			// if we have an API key, keep using it till it expires
			return Promise (apiKey)
		}
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
			.then(on: .global()) { (key: GoogleAPIKey) -> GoogleAPIKey in
				self.apiKey = key // update API key
				// update the expires in value
				self.apiKey!.expiresIn = Date().addingTimeInterval(key.expiresIn.timeIntervalSince1970)
				return self.apiKey!
			}
	}
}
