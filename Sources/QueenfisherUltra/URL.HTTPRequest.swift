//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/10/20.
//

import Foundation
import Promises

/// Extensions to make HTTP requests quickly
public extension URL {
	
	static var defaultEncoder: JSONEncoder = {
		let encoder = JSONEncoder()
		encoder.keyEncodingStrategy = .convertToSnakeCase
		encoder.dateEncodingStrategy = .secondsSince1970
		return encoder
	}()
	static var defaultDecoder: JSONDecoder = {
		let encoder = JSONDecoder()
		encoder.keyDecodingStrategy = .convertFromSnakeCase
		encoder.dateDecodingStrategy = .secondsSince1970
		return encoder
	}()
	
	enum HTTPError: Error {
		case noData
		case decodingError (Data)
	}
	
	func httpRequest (request: URLRequest) throws -> Promise<Data> {
		let promise = Promise <Data>.pending()
		URLSession.shared.dataTask(with: request) { (data, response, error) in
			if let error = error {
				promise.reject(error)
			} else if let data = data {
				promise.fulfill(data)
			} else {
				promise.reject(HTTPError.noData)
			}
		}
		.resume()
		return promise
	}
	func httpRequest <O: Decodable, E: Error & Codable> (request: URLRequest,
														 decoder: JSONDecoder,
														 errorType: E.Type) throws -> Promise<O> {
		try httpRequest(request: request)
		.then(on: .global()) { data -> O in
			let decoder = JSONDecoder ()
			decoder.keyDecodingStrategy = .convertFromSnakeCase
			decoder.dateDecodingStrategy = .secondsSince1970
			
			do {
				let object = try decoder.decode(O.self, from: data)
				return object
			} catch {
				print (error)
				let err: E
				do {
					err = try decoder.decode(E.self, from: data)
				} catch {
					print (String(data: data, encoding: .utf8)!)
					throw error
				}
				throw err
			}
		}
	}
	func httpRequest (headers: [String:String], method: String = "GET") throws -> Promise<Data> {
		var request = URLRequest (url: self)
		
		for (key, value) in headers {
			request.addValue(value, forHTTPHeaderField: key)
		}
		request.httpMethod = method
		return try httpRequest(request: request)
	}
	func httpRequest <O: Decodable, E: Error & Codable> (headers: [String:String],
									 method: String = "GET",
									 decoder: JSONDecoder = URL.defaultDecoder,
									 errorType: E.Type) throws -> Promise<O> {
		var request = URLRequest (url: self)
		
		for (key, value) in headers {
			request.addValue(value, forHTTPHeaderField: key)
		}
		request.httpMethod = method
		return try httpRequest(request: request, decoder: decoder, errorType: errorType)
	}
	func httpRequest <I: Encodable, O: Decodable, E: Error & Codable> (headers: [String:String],
												   body: I,
												   method: String = "POST",
												   encoder: JSONEncoder = URL.defaultEncoder,
												   decoder: JSONDecoder = URL.defaultDecoder,
												   errorType: E.Type) throws -> Promise<O> {
		var request = URLRequest (url: self)
		for (key, value) in headers {
			request.addValue(value, forHTTPHeaderField: key)
		}
		request.addValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try encoder.encode(body)
		request.httpMethod = method
		request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
		
		return try httpRequest(request: request, decoder: decoder, errorType: errorType)
	}
	
}
