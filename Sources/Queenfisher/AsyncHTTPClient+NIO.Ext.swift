//
//  AsyncHTTPClient+NIO.Ext.swift
//  
//
//  Created by Adhiraj Singh on 6/1/20.
//
import Foundation
import NIO
import NIOHTTP1
import AsyncHTTPClient

var defaultEncoder: JSONEncoder = {
	let encoder = JSONEncoder()
	encoder.keyEncodingStrategy = .convertToSnakeCase
	encoder.dateEncodingStrategy = .secondsSince1970
	encoder.dataEncodingStrategy = .base64
	return encoder
}()
var defaultDecoder: JSONDecoder = {
	let decoder = JSONDecoder()
	decoder.keyDecodingStrategy = .convertFromSnakeCase
	decoder.dateDecodingStrategy = .secondsSince1970
	decoder.dataDecodingStrategy = .custom({ (decoder) -> Data in
		let container = try decoder.singleValueContainer()
		let decodedStr = try container.decode(String.self) // URL decode
						.replacingOccurrences(of: "_", with: "/")
						.replacingOccurrences(of: "-", with: "+")
		if let data = Data(base64Encoded: decodedStr) {
			return data
		}
		throw DecodingError.dataCorruptedError(in: container, debugDescription: "Data corrupted")
	})
	return decoder
}()

public extension HTTPClient {

	enum HTTPError: Error {
		case noData (HTTPClient.Response)
		case decodingError (Error, Error, Data)
	}
	func execute (request: HTTPClient.Request) -> EventLoopFuture<Data> {
		execute(request: request)
		.flatMapThrowing { (response: Response) throws -> Data in
			guard let buff = response.body else {
				throw HTTPError.noData (response)
			}
			return Data(buffer: buff)
		}
	}
	func execute <O: Decodable, E: Error & Codable> (request: HTTPClient.Request, errorType: E.Type) -> EventLoopFuture<O> {
		execute(request: request)
		.flatMapThrowing { data -> O in
			do {
				let object = try defaultDecoder.decode(O.self, from: data)
				return object
			} catch let err0 {
				
				let err: E
				do {
					err = try defaultDecoder.decode(E.self, from: data)
				} catch let err1 {
					print ("resp:" + String(data: data, encoding: .utf8)!)
					throw HTTPError.decodingError(err0, err1, data)
				}
				throw err
			}
		}
	}
	func execute <O: Decodable, E: Error & Codable> (url: URL,
													 headers: [(String,String)],
													 method: HTTPMethod = .GET,
													 errorType: E.Type) throws -> EventLoopFuture<O> {
		execute(request: try .init(url: url, method: method, headers: .init(headers)), errorType: errorType)
	}
	func execute <I: Encodable, O: Decodable, E: Error & Codable> (url: URL,
																   headers: [(String,String)],
																   body: I,
																   method: HTTPMethod = .GET,
																   errorType: E.Type) throws -> EventLoopFuture<O> {
		var request: HTTPClient.Request
		if method == .GET {
			let dict: [String:Any] = try JSONSerialization.jsonObject(with: try defaultEncoder.encode(body), options: []) as! [String:Any]
			var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
			let query = dict.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
			comps.queryItems = query
			//print(comps.url!)
			request = try .init (url: comps.url!, method: method)
		} else {
			request = try .init (url: url, method: method)
			request.headers.add(name: "Content-Type", value: "application/json")
			request.body = .data(try defaultEncoder.encode(body))
		}
		request.headers.add(contentsOf: headers)
		
		return execute(request: request, errorType: errorType)
	}
	
}
public extension EventLoopFuture {
	
	func flatMapThrowing <NewValue> (_ callback: @escaping (Value) throws -> EventLoopFuture<NewValue>) -> EventLoopFuture<NewValue> {
		flatMapThrowing(callback).flatMap { $0 }
	}
	func delay (_ time: TimeAmount) -> EventLoopFuture<Value> {
		flatMap { value in self.eventLoop.scheduleTask(in: time) { value }.futureResult }
	}
}
