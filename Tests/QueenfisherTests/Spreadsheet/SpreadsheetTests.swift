import XCTest
import Promises
@testable import Queenfisher

final class SpreadsheetTests: XCTestCase {
	let testSheetTitle = "My Test"
	
	let data2write = [["hello", "this", "is", "jeff"],
					  ["yes", "my", "name", "jeff"],
					  ["of course", "this", "is", "jeff"],
					  ["okay", "got", "it", "jeff"]]
	
	let queue = DispatchQueue.global()
	var sheet: Spreadsheet!
	
	override func setUp() {
		let auth = AuthenticationTests().getFactory(for: .sheets)!
		XCTAssertNoThrow(sheet = try await (Spreadsheet.get(testSpreadsheetId, using: auth)))
		createSheetIfRequired()
	}
	override func tearDown() {
		sheet = nil
	}
	func testGetSpreadsheet () {
		if let sheet = sheet {
			print("Got spreadsheet '\(sheet.properties.title)', sheets: \(sheet.sheets.map({$0.properties.title}))")
		}
	}
	func createSheetIfRequired () {
		if sheet!.sheet(forTitle: testSheetTitle) != nil {
			return
		}
		XCTAssertNoThrow(try await(sheet!.create(title: testSheetTitle, dimensions: .init(rowCount: 10, columnCount: 5))))
		XCTAssertNotNil(sheet!.sheet(forTitle: testSheetTitle))
		if let newSheet = sheet!.sheet(forTitle: testSheetTitle)?.properties {
			print ("Created sheet: \(newSheet.title), id: \(newSheet.sheetId!)")
		}
	}
	func testCreateSheet () {
		if sheet!.sheet(forTitle: testSheetTitle) != nil {
			testDeleteSheet()
		}
		createSheetIfRequired()
	}
	func testDeleteSheet () {
		guard let sheetId = sheet!.sheet(forTitle: testSheetTitle)?.properties.sheetId else {
			XCTFail("Test sheet not present")
			return
		}
		XCTAssertNoThrow(_ = try await(sheet!.delete(sheetId: sheetId)))
		XCTAssertNil(sheet!.sheet(forTitle: testSheetTitle))
	}
	func testClearSheet () {
		let sheetId = sheet!.sheet(forTitle: testSheetTitle)!.properties.sheetId!
		let task = sheet!.clear(sheetId: sheetId)
			.then(on: queue) { _ in self.sheet!.read(sheet: self.testSheetTitle, range: (.column(0), .column(4))) }
			.then (on: queue) { XCTAssertNil ($0.values) }
		XCTAssertNoThrow(_ = try await(task))
	}
	func testReadSheet () {
		XCTAssertNoThrow(_ = try await(sheet!.read(sheet: testSheetTitle)))
	}
	func testAppend () {
		let sheetId = sheet!.sheet(forTitle: testSheetTitle)!.properties.sheetId!
		var oldEnd: Sheet.Location? = nil
		let task = sheet!.read(sheet: self.testSheetTitle)
			.then(on: queue) { oldEnd = $0.end }
			.then(on: queue) { _ in self.sheet!.append(sheetId: sheetId, size: 5, dimension: .columns) }
			.then(on: queue) { _ in self.sheet!.read(sheet: self.testSheetTitle) }
			.then(on: queue) { XCTAssertEqual((oldEnd! + (5, 0)).description, $0.end.description) }
		
		XCTAssertNoThrow(try await(task))
	}
	func testAppendRows () {
		let sheetId = sheet!.sheet(forTitle: testSheetTitle)!.properties.sheetId!
		let rows = [["hello", "how", "we", "doing"],
					["good", "i", "guess"]]
		//var oldEnd: Sheet.Location? = nil
		let task = sheet!.appendRows(sheetId: sheetId, rows: rows)
			.then(on: queue) { _ in self.sheet!.read(sheet: self.testSheetTitle) }
			.then(on: queue) { XCTAssertEqual(rows, $0.values!.suffix(rows.count)) }
		XCTAssertNoThrow(try await(task))
	}
	func testWrite () {
		let start: Sheet.Location = .cell(0, 0)
		let end: Sheet.Location = .cell(data2write[0].count-1, data2write.count-1)
		let task = sheet!.write(sheet: self.testSheetTitle,
								data: self.data2write,
								starting: start,
								dimension: .rows)
			.then(on: queue) { _ in self.sheet!.read(sheet: self.testSheetTitle, range: (start, end)) }
			.then (on: queue) { XCTAssertEqual(self.data2write, $0.values) }
		XCTAssertNoThrow(try await(task))
	}
	func testWriteRows () {
		let sheetId = sheet.sheet(forTitle: testSheetTitle)!.properties.sheetId!
		let start: Sheet.Location = .cell(0, 0)
		let end: Sheet.Location = .cell(data2write[0].count-1, data2write.count-1)
		let task = sheet!.writeRows(sheetId: sheetId,
									rows: self.data2write,
									starting: start)
			.then(on: queue) { _ in self.sheet!.read(sheet: self.testSheetTitle, range: (start, end)) }
			.then (on: queue) { XCTAssertEqual(self.data2write, $0.values) }
		XCTAssertNoThrow(try await(task))
	}
	func testMove () {
		testWriteRows()
		let sheetId = sheet!.sheet(forTitle: testSheetTitle)!.properties.sheetId!
		let pIndex = 3
		let rRange = 1..<2
		
		var expected = data2write
		let rows = rRange.map { _ in expected.remove(at: rRange.lowerBound) }
		
		if pIndex < rRange.lowerBound {
			expected.insert(contentsOf: rows, at: pIndex)
		} else if pIndex > rRange.upperBound {
			expected.insert(contentsOf: rows, at: pIndex-(rRange.upperBound-rRange.lowerBound))
		}
		
		let start: Sheet.Location = .cell(0, 0)
		let end: Sheet.Location = .cell(data2write[0].count-1, data2write.count-1)
		let task = sheet!.move(sheetId: sheetId, range: rRange, to: pIndex, dimension: .rows)
			.then(on: queue) { _ in self.sheet!.read(sheet: self.testSheetTitle, range: (start, end)) }
			.then (on: queue) { XCTAssertEqual(expected, $0.values) }
		XCTAssertNoThrow(try await(task))
	}
	func testDelete () throws {
		testClearSheet()
		testWrite()
		
		let sheetId = sheet!.sheet(forTitle: testSheetTitle)!.properties.sheetId!
		
		let rowRemoveRange = 1..<3
		let colRemoveRange = 0..<1
		
		var modifiedData1 = data2write
		modifiedData1.removeSubrange(rowRemoveRange)
		var modifiedData2 = modifiedData1.map { $0 }
		for i in 0..<modifiedData2.count {
			modifiedData2[i].removeSubrange(colRemoveRange)
		}
		
		let task = sheet!.delete(sheetId: sheetId, range: rowRemoveRange, dimension: .rows)
			.then(on: queue) { _ in self.sheet!.read(sheet: self.testSheetTitle, range: (.column(0), .column(3))) }
			.then (on: queue) { XCTAssertEqual(modifiedData1, $0.values) }
			.then(on: queue) { self.sheet!.delete(sheetId: sheetId,
												  range: colRemoveRange,
												  dimension: .columns) }
			.then(on: queue) { _ in self.sheet!.read(sheet: self.testSheetTitle, range: (.column(0), .column(3))) }
			.then (on: queue) { XCTAssertEqual(modifiedData2, $0.values) }
		XCTAssertNoThrow(try await(task))
	}
	func testInsert () throws {
		testClearSheet()
		testWrite()
		
		let sheetId = sheet!.sheet(forTitle: testSheetTitle)!.properties.sheetId!
		let rowAddRange = 1..<4
		
		var modifiedData1 = data2write
		for _ in rowAddRange {
			modifiedData1.insert([], at: rowAddRange.lowerBound)
		}
		
		let task = sheet!.insert(sheetId: sheetId, range: rowAddRange, dimension: .rows)
			.then(on: queue) { _ in self.sheet!.read(sheet: self.testSheetTitle, range: (.column(0), .column(4))) }
			.then (on: queue) { XCTAssertEqual(modifiedData1, $0.values) }
		XCTAssertNoThrow(try await(task))
	}

    static var allTests = [
        ("testGetSpreadsheet", testGetSpreadsheet),
    ]
}
