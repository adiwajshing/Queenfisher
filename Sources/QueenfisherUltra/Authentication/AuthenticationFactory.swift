//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/21/20.
//

import Foundation
import Promises

protocol AuthenticationFactory: class, Authenticator {
	var apiKeys: [GoogleScope:Promise<GoogleAPIKey>] { get set }
	var queue: DispatchQueue { get }
	
	func getKey (scope: GoogleScope) throws -> Promise<GoogleAPIKey>
}
extension AuthenticationFactory {
	
	public func authenticate (scope: GoogleScope) throws -> Promise<GoogleAPIKey> {
		let generateKeyPromise = { (scope: GoogleScope) throws -> Promise<GoogleAPIKey> in
			print("Renewing API key for \(scope)...")
			return try self.getKey(scope: scope)
				.then(on: self.queue) { $0.with(expiry: Date().addingTimeInterval($0.expiresIn.timeIntervalSince1970)) }
				.catch(on: self.queue) { _ in self.apiKeys[scope] = nil }
		}
		
		return Promise(())
		.then(on: queue) { _ -> Promise<GoogleAPIKey> in
			if let p = self.apiKeys[scope] {
				return p
			} else {
				let p = try generateKeyPromise(scope)
				self.apiKeys[scope] = p
				return p
			}
		}
		.then(on: queue) { key -> Promise<GoogleAPIKey> in
			if key.isExpired {
				let p = try generateKeyPromise(scope)
				self.apiKeys[scope] = p
				return p
			} else {
				return .init(key)
			}
		}
	}
}
extension AuthenticationFactory where Self: Decodable {
	
	/// Load an authentication factory from a JSON stored in a file.
	/// This file is usually the one downloaded after you create a client ID or service account
	static func loading (fromJSONAt url: URL) throws -> Self {
		let data = try Data (contentsOf: url)
		let decoder = JSONDecoder ()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		let obj = try decoder.decode(Self.self, from: data)
		obj.queue.sync { }
		return obj
	}
	
}
