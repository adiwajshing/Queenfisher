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
		encoder.dataEncodingStrategy = .base64
		return encoder
	}()
	static var defaultDecoder: JSONDecoder = {
		let decoder = JSONDecoder()
		decoder.keyDecodingStrategy = .convertFromSnakeCase
		decoder.dateDecodingStrategy = .secondsSince1970
		decoder.dataDecodingStrategy = .custom({ (decoder) -> Data in
			let container = try decoder.singleValueContainer()
			let decodedStr = try container.decode(String.self)
							.replacingOccurrences(of: "_", with: "/")
							.replacingOccurrences(of: "-", with: "+")
			if let data = Data(base64Encoded: decodedStr) {
				return data
			}
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "Data corrupted")
		})
		return decoder
	}()
	
	enum HTTPError: Error {
		case noData
		case decodingError (Error, Error, Data)
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
			//print ("resp:" + String(data: data, encoding: .utf8)!)
			do {
				let object = try decoder.decode(O.self, from: data)
				return object
			} catch let err0 {
				
				let err: E
				do {
					err = try decoder.decode(E.self, from: data)
				} catch let err1 {
					print ("resp:" + String(data: data, encoding: .utf8)!)
					throw HTTPError.decodingError(err0, err1, data)
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
		var request: URLRequest
		if method == "GET" {
			let dict: [String:Any] = try JSONSerialization.jsonObject(with: try encoder.encode(body), options: []) as! [String:Any]
			
			var comps = URLComponents(url: self, resolvingAgainstBaseURL: false)!
			let query = dict.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
			comps.queryItems = query
			//print(comps.url!)
			request = URLRequest (url: comps.url!)
		} else {
			request = URLRequest (url: self)
			request.addValue("application/json", forHTTPHeaderField: "Content-Type")
			request.httpBody = try encoder.encode(body)
		}
		for (key, value) in headers {
			request.addValue(value, forHTTPHeaderField: key)
		}
		request.httpMethod = method
		request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
		
		return try httpRequest(request: request, decoder: decoder, errorType: errorType)
	}
	
}
