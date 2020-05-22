import XCTest
import Promises
@testable import QueenfisherUltra

final class SpreadsheetTests: XCTestCase {
	let testSheetTitle = "My Test"
	
	let data2write = [["hello", "this", "is", "jeff"],
					  ["yes", "my", "name", "jeff"],
					  ["of course", "this", "is", "jeff"],
					  ["okay", "got", "it", "jeff"]]
	
	let queue = DispatchQueue.global()
	
	var sheet: Spreadsheet<GoogleServiceAccount>!
	var auth = AuthenticationTests ()
	
	func testGetSpreadsheet () {
		if auth.acc == nil {
			auth.testServiceAccountAuth()
		}
		if sheet == nil {
			XCTAssertNoThrow(sheet = try await (Spreadsheet.get(testSpreadsheetId, using: auth.acc)))
			if let sheet = sheet {
				print("Got spreadsheet '\(sheet.properties.title)', sheets: \(sheet.sheets.map({$0.properties.title}))")
			}
		}
	}
	func testCreateSheet () {
		testGetSpreadsheet()
		
		if sheet!.sheet(forTitle: testSheetTitle) != nil {
			return
		}
		//var response: Spreadsheet<GoogleServiceAccount>.UpdateResponse!
		XCTAssertNoThrow(_ = try await(sheet!.create(title: testSheetTitle,
													 dimensions: .init(rowCount: 10, columnCount: 5))))
		XCTAssertNotNil(sheet!.sheet(forTitle: testSheetTitle))
		if let newSheet = sheet!.sheet(forTitle: testSheetTitle)?.properties {
			print ("Created sheet: \(newSheet.title), id: \(newSheet.sheetId!)")
		}
	}
	func testDeleteSheet () {
		testGetSpreadsheet()
		
		if sheet!.sheet(forTitle: testSheetTitle) == nil {
			testCreateSheet()
		}
		guard let sheetId = sheet!.sheet(forTitle: testSheetTitle)?.properties.sheetId else {
			XCTFail("Test sheet not present")
			return
		}
		
		//var response: Spreadsheet<GoogleServiceAccount>.UpdateResponse!
		XCTAssertNoThrow(_ = try await(sheet!.delete(sheetId: sheetId)))
		XCTAssertNil(sheet!.sheet(forTitle: testSheetTitle))
	}
	func testClearSheet () {
		testGetSpreadsheet()
		
		guard let sheetId = sheet!.sheet(forTitle: testSheetTitle)?.properties.sheetId else {
			XCTFail("Test sheet not present")
			return
		}
		
		let task = Promise(())
			.then(on: queue) { try self.sheet!.clear(sheetId: sheetId) }
			.then(on: queue) { _ in try self.sheet!.read(sheet: self.testSheetTitle,
														 range: (.column(0), .column(4))) }
			.then (on: queue) { XCTAssertNil ($0.values) }
		XCTAssertNoThrow(_ = try await(task))
	}
	func testReadSheet () {
		testGetSpreadsheet()
		let task = Promise(())
			.then(on: queue) { try self.sheet!.read(sheet: "Studentssd") }
			.then(on: queue) { print ($0) }
		XCTAssertNoThrow(_ = try await(task))
	}
	func testAppend () {
		testGetSpreadsheet()
		
		if sheet!.sheet(forTitle: testSheetTitle) == nil {
			testCreateSheet()
		}
		let sheetId = sheet!.sheet(forTitle: testSheetTitle)!.properties.sheetId!
		var oldEnd: Sheet.Location? = nil
		let task = Promise(())
			.then(on: queue) { _ in try self.sheet!.read(sheet: self.testSheetTitle) }
			.then(on: queue) { oldEnd = $0.end }
			.then(on: queue) { _ in try self.sheet!.append(sheetId: sheetId, size: 5, dimension: .columns) }
			.then(on: queue) { _ in try self.sheet!.read(sheet: self.testSheetTitle) }
			.then(on: queue) { XCTAssertEqual((oldEnd! + (5, 0)).description, $0.end.description) }
		
		XCTAssertNoThrow(_ = try await(task))
	}
	func testAppendRows () {
		testGetSpreadsheet()
		
		if sheet!.sheet(forTitle: testSheetTitle) == nil {
			testCreateSheet()
		}
		let sheetId = sheet!.sheet(forTitle: testSheetTitle)!.properties.sheetId!
		let rows = [["hello", "how", "we", "doing"],
					["good", "i", "guess"]]
		//var oldEnd: Sheet.Location? = nil
		let task = Promise(())
			.then(on: queue) { _ in try self.sheet!.appendRows(sheetId: sheetId, rows: rows) }
			.then(on: queue) { _ in try self.sheet!.read(sheet: self.testSheetTitle) }
			.then(on: queue) { XCTAssertEqual(rows, $0.values!.suffix(rows.count)) }
		XCTAssertNoThrow(_ = try await(task))
	}
	func testWrite () {
		testGetSpreadsheet()
		
		if sheet!.sheet(forTitle: testSheetTitle) == nil {
			testCreateSheet()
		}
		let start: Sheet.Location = .cell(0, 0)
		let end: Sheet.Location = .cell(data2write[0].count-1, data2write.count-1)
		let task = Promise(())
			.then(on: queue) { try self.sheet!.write(sheet: self.testSheetTitle,
													 data: self.data2write,
													 starting: start,
													 dimension: .rows) }
			.then(on: queue) { _ in try self.sheet!.read(sheet: self.testSheetTitle, range: (start, end)) }
			.then (on: queue) { XCTAssertEqual(self.data2write, $0.values) }
		XCTAssertNoThrow(_ = try await(task))
	}
	func testWriteRows () {
		testGetSpreadsheet()
		
		if sheet!.sheet(forTitle: testSheetTitle) == nil {
			testCreateSheet()
		}
		let sheetId = sheet.sheet(forTitle: testSheetTitle)!.properties.sheetId!
		let start: Sheet.Location = .cell(0, 0)
		let end: Sheet.Location = .cell(data2write[0].count-1, data2write.count-1)
		let task = Promise(())
			.then(on: queue) { try self.sheet!.writeRows(sheetId: sheetId,
														 rows: self.data2write,
														 starting: start) }
			.then(on: queue) { _ in try self.sheet!.read(sheet: self.testSheetTitle, range: (start, end)) }
			.then (on: queue) { XCTAssertEqual(self.data2write, $0.values) }
		XCTAssertNoThrow(_ = try await(task))
	}
	func testMove () {
		testWriteRows()
		
		guard let sheetId = sheet!.sheet(forTitle: testSheetTitle)?.properties.sheetId else {
			XCTFail("Test sheet not present")
			return
		}
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
		let task = Promise(())
			.then(on: queue) { try self.sheet!.move(sheetId: sheetId, range: rRange, to: pIndex, dimension: .rows) }
			.then(on: queue) { _ in try self.sheet!.read(sheet: self.testSheetTitle, range: (start, end)) }
			.then (on: queue) { XCTAssertEqual(expected, $0.values) }
		XCTAssertNoThrow(_ = try await(task))
	}
	func testDelete () throws {
		testClearSheet()
		testWrite()
		
		guard let sheetId = sheet!.sheet(forTitle: testSheetTitle)?.properties.sheetId else {
			XCTFail("Test sheet not present")
			return
		}
		
		let rowRemoveRange = 1..<3
		let colRemoveRange = 0..<1
		
		var modifiedData1 = data2write
		modifiedData1.removeSubrange(rowRemoveRange)
		var modifiedData2 = modifiedData1.map { $0 }
		for i in 0..<modifiedData2.count {
			modifiedData2[i].removeSubrange(colRemoveRange)
		}
		
		let task = Promise(())
		.then(on: queue) { try self.sheet!.delete(sheetId: sheetId,
												  range: rowRemoveRange,
												  dimension: .rows) }
		.then(on: queue) { _ in try self.sheet!.read(sheet: self.testSheetTitle, range: (.column(0), .column(3))) }
		.then (on: queue) { XCTAssertEqual(modifiedData1, $0.values) }
		.then(on: queue) { try self.sheet!.delete(sheetId: sheetId,
												  range: colRemoveRange,
												  dimension: .columns) }
		.then(on: queue) { _ in try self.sheet!.read(sheet: self.testSheetTitle, range: (.column(0), .column(3))) }
		.then (on: queue) { XCTAssertEqual(modifiedData2, $0.values) }
		XCTAssertNoThrow(_ = try await(task))
	}
	
	/*func testDelete2 () throws {
		testClearSheet()
		testWrite()
		
		guard let sheetId = sheet!.sheet(forTitle: testSheetTitle)?.properties.sheetId else {
			XCTFail("Test sheet not present")
			return
		}
		
		let ops = Spreadsheet<GoogleServiceAccount>.Operations (requests: [
						.delete(sheetId: sheetId, range: 0..<1, dimension: .rows),
						.delete(sheetId: sheetId, range: 2..<3, dimension: .rows)
					])
		let task = Promise(())
			.then(on: queue) { try self.sheet.batchUpdate(ops) }
		XCTAssertNoThrow(_ = try await(task))
	}*/
	func testInsert () throws {
		testClearSheet()
		testWrite()
		
		guard let sheetId = sheet!.sheet(forTitle: testSheetTitle)?.properties.sheetId else {
			XCTFail("Test sheet not present")
			return
		}
		
		let rowAddRange = 1..<4
		
		var modifiedData1 = data2write
		for _ in rowAddRange {
			modifiedData1.insert([], at: rowAddRange.lowerBound)
		}
		
		let task = Promise(())
		.then(on: queue) { try self.sheet!.insert(sheetId: sheetId,
												  range: rowAddRange,
												  dimension: .rows) }
		.then(on: queue) { _ in try self.sheet!.read(sheet: self.testSheetTitle, range: (.column(0), .column(4))) }
		.then (on: queue) { XCTAssertEqual(modifiedData1, $0.values) }
		XCTAssertNoThrow(_ = try await(task))
	}

    static var allTests = [
        ("testGetSpreadsheet", testGetSpreadsheet),
    ]
}
