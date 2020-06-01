//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/17/20.
//

import Foundation
import NIO
import AsyncHTTPClient

let sheetsApiUrl = URL (string: "https://sheets.googleapis.com/v4/spreadsheets/")!
/// Generic Spreadsheet with functions to batch update
public protocol SheetInteractable {
	var spreadsheetId: String {get}
	var authenticator: Authenticator? {get}
	var client: HTTPClient! {get}
}
public extension SheetInteractable {
	
	var url: URL { sheetsApiUrl.appendingPathComponent(spreadsheetId) }
	
	/// Write Columned or Rowed data to the sheet
	func write (sheet: String? = nil, data: [[String]], starting from: Sheet.Location, dimension: Sheet.Dimension) -> EventLoopFuture<Spreadsheet.WriteResponse> {
		let range = (sheet != nil ? "\(sheet!)!" : "") + from.celled().description
		
		var url = self.url.appendingPathComponent("values").appendingPathComponent(range)
		var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
		comps.queryItems = [URLQueryItem(name: "valueInputOption", value: "USER_ENTERED")]
		url = comps.url!
		
		let body = Sheet.ValuesRange(dimension: dimension, range: range, values: data)
		return authenticating()
			.flatMapThrowing {
				try self.client!.execute(url: url,
										 headers: $0,
										 body: body,
										 method: .PUT,
										 errorType: ErrorResponse.self)
			}
	}
	/// Read a sheet
	func read (sheet: String? = nil, range: (from: Sheet.Location, to: Sheet.Location)? = nil) -> EventLoopFuture<Sheet.ValuesRange> {
		var url = self.url.appendingPathComponent("values")
		if var sheetComp = sheet {
			if let range = range {
				sheetComp += "!\(range.from.description):\(range.to.description)"
			}
			url.appendPathComponent(sheetComp)
		}
		return authenticating().flatMapThrowing { try self.client!.execute(url: url, headers: $0, errorType: ErrorResponse.self) }
	}
	func batchUpdate (_ operation: Spreadsheet.Operation) -> EventLoopFuture<Spreadsheet.UpdateResponse> {
		batchUpdate(operations: .init(operation))
	}
	func batchUpdate (operations: Spreadsheet.Operations) -> EventLoopFuture<Spreadsheet.UpdateResponse> {
		let url = sheetsApiUrl.appendingPathComponent(spreadsheetId + ":batchUpdate")
		return authenticating().flatMapThrowing {
			try self.client!.execute(url: url,
										 headers: $0,
										 body: operations,
										 method: .POST,
										 errorType: ErrorResponse.self)
		}
	}
	internal func authenticating () -> EventLoopFuture<[(String,String)]> {
		authenticator!.authenticationHeader(scope: .sheets, client: client!).map { [$0] }
	}
}
