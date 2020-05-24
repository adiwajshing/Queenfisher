//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/17/20.
//

import Foundation
import Promises

let sheetsApiUrl = URL (string: "https://sheets.googleapis.com/v4/spreadsheets/")!

public protocol SheetInteractable {
	var spreadsheetId: String {get}
	var authenticator: Authenticator? {get}
	var queue: DispatchQueue {get}
}
public extension SheetInteractable {
	
	var url: URL { sheetsApiUrl.appendingPathComponent(spreadsheetId) }

	func write (sheet: String? = nil, data: [[String]], starting from: Sheet.Location, dimension: Sheet.Dimension) -> Promise<Sheet.WriteResponse> {
		let range = (sheet != nil ? "\(sheet!)!" : "") + from.celled().description
		
		var url = self.url.appendingPathComponent("values").appendingPathComponent(range)
		var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
		comps.queryItems = [URLQueryItem(name: "valueInputOption", value: "USER_ENTERED")]
		url = comps.url!
		
		let body = Sheet.ValuesRange(dimension: dimension, range: range, values: data)
		return authenticating()
			.then (on: queue) { try url.httpRequest(headers: $0,
													body: body,
													method: "PUT",
													errorType: Sheet.ErrorResponse.self) }
	}
	func read (sheet: String? = nil, range: (from: Sheet.Location, to: Sheet.Location)? = nil) -> Promise<Sheet.ValuesRange> {
		var url = self.url.appendingPathComponent("values")
		if var sheetComp = sheet {
			if let range = range {
				sheetComp += "!\(range.from.description):\(range.to.description)"
			}
			url.appendPathComponent(sheetComp)
		}
		return authenticating()
			.then(on: queue) { try url.httpRequest(headers: $0, errorType: Sheet.ErrorResponse.self) }
	}
	func batchUpdate (_ operation: Sheet.Operation) -> Promise<Sheet.UpdateResponse> {
		batchUpdate(operations: .init(operation))
	}
	func batchUpdate (operations: Sheet.Operations) -> Promise<Sheet.UpdateResponse> {
		let url = sheetsApiUrl.appendingPathComponent(spreadsheetId + ":batchUpdate")
		return authenticating()
		.then (on: queue) { try url.httpRequest(headers: $0,
												body: operations,
												method: "POST",
												errorType: Sheet.ErrorResponse.self) }
	}
	internal func authenticating () -> Promise<[String:String]> {
		authenticator!.authenticationHeaders(scope: .sheets)
	}
}
