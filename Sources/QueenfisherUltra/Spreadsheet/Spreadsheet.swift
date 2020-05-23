import Promises
import Foundation

public class Spreadsheet: SheetInteractable, Decodable {
	
	public struct Properties: Codable {
		let title: String
	}
	public let spreadsheetId: String
	public let properties: Properties
	public let spreadsheetUrl: URL
	
	private(set) public var sheets: [Sheet]
	private(set) public var authenticator: Authenticator?
	public let queue = DispatchQueue.global()
	
	/// Custom decoding init to allow `DispatchQueue` & `Authenticator` properties
	public required init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		spreadsheetId = try container.decode(String.self, forKey: CodingKeys.spreadsheetId)
		properties = try container.decode(Properties.self, forKey: CodingKeys.properties)
		spreadsheetUrl = try container.decode(URL.self, forKey: CodingKeys.spreadsheetUrl)
		sheets = try container.decode([Sheet].self, forKey: CodingKeys.sheets)
	}
	public static func get (_ spreadsheetId: String, using authenticator: Authenticator) throws -> Promise<Spreadsheet> {
		let url = sheetsApiUrl.appendingPathComponent(spreadsheetId)
		let queue: DispatchQueue = .global()
		return try authenticator.authenticationHeaders(scope: .sheets)
		.then(on: queue) { try url.httpRequest(headers: $0,
											   method: "GET",
											   decoder: JSONDecoder(),
											   errorType: Sheet.ErrorResponse.self) }
		.then(on: queue) { $0.authenticator = authenticator }
	}
	
	public func sheet (forTitle title: String) -> Sheet? {
		sheets.first(where: {$0.properties.title == title})
	}
	
	public func writeRows (sheetId: Int, rows: [[String]], starting from: Sheet.Location) throws -> Promise<Sheet.UpdateResponse> {
		try batchUpdate(.updateCells(sheetId: sheetId, rows: rows, start: from))
	}
	public func create (title: String, dimensions grid: Sheet.Properties.Grid?) throws -> Promise<Sheet.UpdateResponse> {
		try batchUpdate(.addSheet(title: title, grid: grid))
			.then (on: queue) {
				let addSheet = $0.replies.first!.addSheet!.properties
				self.sheets.append(.init(properties: .init(title: addSheet!.title,
														   sheetId: addSheet!.sheetId!,
														   index: self.sheets.count,
														   sheetType: .grid,
														   hidden: nil,
														   rightToLeft: nil,
														   gridProperties: addSheet!.gridProperties!),
										 data: nil))
			}
	}
	public func delete (sheetId: Int) throws -> Promise<Sheet.UpdateResponse> {
		try batchUpdate(.deleteSheet(sheetId: sheetId))
		.then (on: queue) { _ in self.sheets.removeAll(where: {$0.properties.sheetId == sheetId}) }
	}
	public func insert (sheetId: Int, range: Range<Int>, dimension: Sheet.Dimension) throws -> Promise<Sheet.UpdateResponse> {
		try batchUpdate(.insert(sheetId: sheetId, range: range, dimension: dimension))
	}
	public func append (sheetId: Int, size: Int, dimension: Sheet.Dimension) throws -> Promise<Sheet.UpdateResponse> {
		try batchUpdate(.append(sheetId: sheetId, size: size, dimension: dimension))
	}
	func move (sheetId: Int, range: Range<Int>, to dest: Int, dimension: Sheet.Dimension) throws -> Promise<Sheet.UpdateResponse> {
		try batchUpdate(.move(sheetId: sheetId, range: range, to: dest, dimension: dimension))
	}
	public func appendRows (sheetId: Int, rows: [[String]]) throws -> Promise<Sheet.UpdateResponse> {
		try batchUpdate(.appendCells(sheetId: sheetId, rows: rows))
	}
	public func delete (sheetId: Int, range: Range<Int>, dimension: Sheet.Dimension) throws -> Promise<Sheet.UpdateResponse> {
		try batchUpdate(.delete(sheetId: sheetId, range: range, dimension: dimension))
	}
	public func clear (sheetId: Int) throws -> Promise<Sheet.UpdateResponse> {
		try batchUpdate(.clear(sheetId: sheetId))
	}
	
	public enum CodingKeys: String, CodingKey {
		case spreadsheetId = "spreadsheetId"
		case properties = "properties"
		case spreadsheetUrl = "spreadsheetUrl"
		case sheets = "sheets"
	}
}
public extension Spreadsheet {
	static func spreadsheetUrl (forSpreadsheetId id: String) -> URL {
		URL(string: "https://docs.google.com/spreadsheets/d/\(id)/edit")!
	}
}
