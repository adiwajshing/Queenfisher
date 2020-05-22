//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/17/20.
//

import Foundation
import Promises

let sheetsApiUrl = URL (string: "https://sheets.googleapis.com/v4/spreadsheets/")!

public protocol SheetInteractable{
	associatedtype Auth: Authenticator
	
	var spreadsheetId: String {get}
	var authenticator: Auth? {get}
	var queue: DispatchQueue {get}
}
public extension SheetInteractable {
	
	var url: URL { sheetsApiUrl.appendingPathComponent(spreadsheetId) }
	var batchUpdateURL: URL { sheetsApiUrl.appendingPathComponent(spreadsheetId + ":batchUpdate") }

	func write (sheet: String? = nil, data: [[String]], starting from: Sheet.Location, dimension: Sheet.Dimension) throws -> Promise<Sheet.WriteResponse> {
		var url = self.url.appendingPathComponent("values")
		
		let to: Sheet.Location
		if dimension == .columns {
			to = from + (data.count-1, data.last!.count-1)
		} else {
			to = from + (data.last!.count-1, data.count-1)
		}
		var rangeString: String = sheet != nil ? "\(sheet!)!" : ""
		rangeString += "\(from.celled()):\(to)"
		
		url.appendPathComponent(rangeString)
		
		var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
		let query = [URLQueryItem(name: "valueInputOption", value: "USER_ENTERED")]
		comps.queryItems = query
		url = comps.url!
		
		let body = Sheet.ValuesRange(dimension: dimension, range: rangeString, values: data)
		
		return try authenticating()
			.then (on: queue) { try url.httpRequest(headers: $0,
													body: body,
													method: "PUT",
													errorType: Sheet.ErrorResponse.self) }
	}
	func read (sheet: String? = nil, range: (from: Sheet.Location, to: Sheet.Location)? = nil) throws -> Promise<Sheet.ValuesRange> {
		var url = self.url.appendingPathComponent("values")
		if var sheetComp = sheet {
			if let range = range {
				sheetComp += "!\(range.from.description):\(range.to.description)"
			}
			url.appendPathComponent(sheetComp)
		}
		return try authenticating()
			.then(on: queue) { try url.httpRequest(headers: $0, errorType: Sheet.ErrorResponse.self) }
	}
	func batchUpdate (_ operation: Sheet.Operation) throws -> Promise<Sheet.UpdateResponse> {
		try batchUpdate(operations: .init(operation))
	}
	func batchUpdate (operations: Sheet.Operations) throws -> Promise<Sheet.UpdateResponse> {
		try authenticating()
		.then (on: queue) { try self.batchUpdateURL.httpRequest(headers: $0,
																body: operations,
																method: "POST",
																encoder: JSONEncoder(),
																errorType: Sheet.ErrorResponse.self) }
	}
	internal func authenticating () throws -> Promise<[String:String]> {
		try authenticator!.authenticationHeaders(scope: .sheets)
	}
}
