import XCTest
@testable import Queenfisher

final class AtomicSheetTests: XCTestCase {
	
	let data = (0..<300).map { _ in ActivePhoneCall.random() }
	let testSheet = ActivePhoneCall.sheetTitle
	
	var sheet: AtomicSheet!
	let queue: DispatchQueue = .global()
	
	override func setUp() {
		guard let auth = AuthenticationTests ().getFactory(for: .sheets) else {
			XCTFail("Auth nil")
			return
		}
		sheet = .init(spreadsheetId: testSpreadsheetId,
					  sheetTitle: testSheet,
					  using: auth,
					  client: getHttpClient(),
					  delegate: self)
	}
	override func tearDown() {
		sheet = nil
	}
	func testManyAppend () {
		let rows = data.map { $0.row() }
		
		_ = sheet.operate {
			try $0.clear()
			for person in self.data {
				try $0.append(rows: [person.row()])
			}
		}
		waitAndMatch(rows: rows)
	}
	func testManyAppendAndInsert () {
		_ = sheet.operate {
			try $0.clear()
		}
		DispatchQueue.concurrentPerform(iterations: data.count, execute: { i in
			let record = data[i]
			_ = sheet.operate(using: { sheet in
				let index = sheet.data.binarySearch(comparing: ActivePhoneCall.indexer,
													with: record.dbKey())
				if sheet.data.indices.contains(index) {
					try sheet.insert(dimension: .rows, range: index..<(index+1))
					try sheet.set(rows: [record.row()], at: .row(index))
				} else {
					try sheet.append(rows: [record.row()])
				}
			})
		})
		let rows = data.sorted(by: {$0.dbKey() < $1.dbKey()}).map { $0.row() }
		waitAndMatch(rows: rows)
	}
	func testManyDelete () {
		testManyAppendAndInsert()
		let personCountToDelete = data.count/3
		DispatchQueue.concurrentPerform(iterations: personCountToDelete, execute: { i in
			let record = self.data[i]
			_ = sheet.operate(using: { sheet in
				let index = sheet.data.binarySearch(comparing: ActivePhoneCall.indexer, with: record.dbKey())
				if index >= sheet.data.count || ActivePhoneCall.indexer(sheet.data[index]) != record.dbKey() {
					XCTFail("\(record) not found")
					return
				}
				try sheet.delete(dimension: .rows, range: index..<(index+1))
			})
		})
		
		let rows = data.suffix(from: personCountToDelete).sorted(by: { $0.dbKey() < $1.dbKey() })
		waitAndMatch(rows: rows.map { $0.row() })
	}
	func testMove () {
		testManyAppend()
		let start = data.count-15
		let end = start+5
		_ = sheet.operate {
			try $0.move(dimension: .rows, range: start..<end, to: 1)
			try $0.move(dimension: .rows, range: start..<end, to: end+5)
		}
		
		waitAndMatch(rows: try! sheet.get().wait())
	}
	func waitAndMatch (rows: [[String]]) {
		while try! sheet.operationsLeft().wait() > 0 {
			usleep(100*1000)
		}
		let future = sheet.read(sheet: testSheet)
		future.whenSuccess {
			XCTAssertEqual(rows.count, $0.values!.count)
			for i in rows.indices {
				XCTAssertEqual(rows[i], $0.values?[i])
			}
		}
		XCTAssertNoThrow( try future.wait() )
	}
}

extension AtomicSheetTests: AtomicSheetDelegate {
	func operationDidFail(_ sheet: String, operation: Spreadsheet.Operation, error: Error) {
		
	}
	func uploadWillBegin(_ sheet: String, operations: [Spreadsheet.Operation]) {
		print ("will upload \(operations.count) operations")
	}
	func uploadDidSucceed(_ sheet: String, operations: [Spreadsheet.Operation]) {
		print ("uploaded successfully \(operations.count) operations")
	}
	func uploadDidFail(_ sheet: String, operations: [Spreadsheet.Operation], error: Error) {
		print ("failed \(operations.count) operations, error: \(error)")
	}	
}
