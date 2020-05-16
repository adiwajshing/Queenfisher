import Promises
import Foundation

let googleApiUrl = URL (string: "https://sheets.googleapis.com/v4/spreadsheets/")!

public class Spreadsheet<Auth: Authenticator>: Codable {
	
	public let spreadsheetId: String
	public let properties: Properties
	public var sheets: [Sheet]
	public let spreadsheetUrl: URL
	
	var authenticator: Auth?
	
	lazy var queue: DispatchQueue = { .global() } ()
	lazy var url: URL = { googleApiUrl.appendingPathComponent(self.spreadsheetId) } ()
	lazy var batchUpdateURL: URL = { googleApiUrl.appendingPathComponent(self.spreadsheetId + ":batchUpdate") } ()
	
	public static func get (_ spreadsheetId: String, using authenticator: Auth) throws -> Promise<Spreadsheet> {
		let url = googleApiUrl.appendingPathComponent(spreadsheetId)
		let queue: DispatchQueue = .global()
		return try authenticator.authenticationHeaders(scope: .sheets)
		.then(on: queue) { try url.httpRequest(headers: $0,
											   method: "GET",
											   decoder: JSONDecoder(),
											   errorType: ErrorResponse.self) }
		.then(on: queue) { $0.authenticator = authenticator }
	}
	
	public func sheet (forTitle title: String) -> Sheet? {
		sheets.first(where: {$0.properties.title == title})
	}
	public func write (sheet: String? = nil, data: [[String]], starting from: Sheet.Location, dimension: Sheet.Dimension) throws -> Promise<WriteResponse> {
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
		
		let body = Sheet.Data(dimension: dimension, range: rangeString, values: data)
		
		return try authenticating()
			.then (on: queue) { try url.httpRequest(headers: $0,
													body: body,
													method: "PUT",
													errorType: ErrorResponse.self) }
	}
	public func read (sheet: String? = nil, from: Sheet.Location, to: Sheet.Location) throws -> Promise<Sheet.Data> {
		var url = self.url.appendingPathComponent("values")
		if let sheet = sheet {
			url.appendPathComponent("\(sheet)!\(from.description):\(to.description)")
		} else {
			url.appendPathComponent("\(from.description):\(to.description)")
		}
		
		return try authenticating()
			.then(on: queue) { try url.httpRequest(headers: $0, errorType: ErrorResponse.self) }
	}
	public func read (sheet: String) throws -> Promise<Sheet.Data> {
		let url = self.url.appendingPathComponent("values").appendingPathComponent(sheet)
		return try authenticating()
			.then(on: queue) { try url.httpRequest(headers: $0, errorType: ErrorResponse.self) }
	}
	
	
	public func writeRows (sheetId: Int, rows: [[String]], starting from: Sheet.Location) throws -> Promise<UpdateResponse> {
		try batchUpdate(.updateCells(sheetId: sheetId, rows: rows, start: from))
	}
	public func create (title: String, dimensions grid: Sheet.Properties.Grid?) throws -> Promise<UpdateResponse> {
		try batchUpdate(.addSheet(title: title, grid: grid))
			.then (on: queue) {
				let addSheet = $0.replies.first!.addSheet!.properties
				self.sheets.append(.init(properties: .init(sheetId: addSheet.sheetId!,
														   title: addSheet.title,
														   index: self.sheets.count,
														   sheetType: .grid,
														   hidden: nil,
														   rightToLeft: nil,
														   gridProperties: addSheet.gridProperties!)))
			}
	}
	public func delete (sheetId: Int) throws -> Promise<UpdateResponse> {
		try batchUpdate(.deleteSheet(sheetId: sheetId))
		.then (on: queue) { _ in self.sheets.removeAll(where: {$0.properties.sheetId == sheetId}) }
	}
	public func insert (sheetId: Int, range: Range<Int>, dimension: Sheet.Dimension) throws -> Promise<UpdateResponse> {
		try batchUpdate(.insert(sheetId: sheetId, range: range, dimension: dimension))
	}
	public func append (sheetId: Int, size: Int, dimension: Sheet.Dimension) throws -> Promise<UpdateResponse> {
		try batchUpdate(.append(sheetId: sheetId, size: size, dimension: dimension))
	}
	public func appendRows (sheetId: Int, rows: [[String]]) throws -> Promise<UpdateResponse> {
		try batchUpdate(.appendCells(sheetId: sheetId, rows: rows))
	}
	public func delete (sheetId: Int, range: Range<Int>, dimension: Sheet.Dimension) throws -> Promise<UpdateResponse> {
		try batchUpdate(.delete(sheetId: sheetId, range: range, dimension: dimension))
	}
	public func clear (sheetId: Int) throws -> Promise<UpdateResponse> {
		try batchUpdate(.clear(sheetId: sheetId))
	}
	public func batchUpdate (_ operation: Operation) throws -> Promise<UpdateResponse> {
		try batchUpdate(operations: .init(operation))
	}
	public func batchUpdate (operations: Operations) throws -> Promise<UpdateResponse> {
		try authenticating()
		.then (on: queue) { try self.batchUpdateURL.httpRequest(headers: $0,
																body: operations,
																method: "POST",
																encoder: JSONEncoder(),
																errorType: ErrorResponse.self) }
	}
	private func authenticating () throws -> Promise<[String:String]> {
		try authenticator!.authenticationHeaders(scope: .sheets)
	}
}
