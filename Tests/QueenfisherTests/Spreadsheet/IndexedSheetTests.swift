import XCTest
import Promises
@testable import Queenfisher

final class IndexedSheetTests: XCTestCase {
	
	var db = (1..<100).map { _ in ActivePhoneCall.random() }.sorted()
	let sheetTitle = ActivePhoneCall.sheetTitle
	
	var sheet: IndexedSheet<String>!
	let queue: DispatchQueue = .init(label: "serial", attributes: [])
	
	override func setUp() {
		let auth = AuthenticationTests().getFactory(for: .sheets)!
		sheet = .init(spreadsheetId: testSpreadsheetId,
					  sheetTitle: sheetTitle,
					  using: auth,
					  header: ActivePhoneCall.header,
					  indexer: ActivePhoneCall.indexer,
					  delegate: self)
	}
	override func tearDown() {
		sheet = nil
	}
	
	func newDB () {
		db = db.map { _ in ActivePhoneCall.random() }.sorted()
	}
	func testLoadSheet () {
		XCTAssertNoThrow(_ = try await (sheet.get().then(on: queue) { print($0) } ))
	}
	func synchronize () -> Promise<Int> {
		let dbFunc = {
			Promise(())
			.delay(on: self.queue, 3) // delay to simulate delay in loading a DB
			.then(on: self.queue) { self.db.map { $0.row() } }
		}
		return sheet.synchronize(with: dbFunc)
	}
	func testSynchronize () {
		// check that it synchronizes correctly even when the sheet is empty & when the DB is completely different
		for _ in 0..<2 {
			newDB()
			XCTAssertNoThrow(try await( synchronize() ))
			assertMatch()
		}
	}
	
	func executeManyOperations () {
		queue.sync {
			for _ in 0..<100 {
				let op = (0..<5).randomElement()!
				let promise: Promise<Void>
				switch op {
				case 0:
					let index = db.indices.randomElement()!
					db[index].toNumber = String ((1000000000...9999999999).randomElement()!)
					promise = sheet.update(values: db[index].toNumber, for: db[index].dbKey(), offset: 2)
					break
				case 1:
					let index = db.indices.randomElement()!
					let row = db[index].row()
					promise = sheet.delete(row: row)
					db.remove(at: index)
					break
				case 2:
					promise = .init(())
					break
				default:
					let p = ActivePhoneCall.random()
					promise = sheet.place(row: p.row())
					if let index = db.firstIndex(where: { $0 > p }) {
						db.insert(p, at: index)
					} else {
						db.append(p)
					}
					break
				}
				promise.then(on: queue) {  }
			}
		}
	}
	
	func testManyOperations () {
		_ = synchronize()
		// test twice, once before synchronization is done & once after
		for _ in 0..<2 {
			executeManyOperations()
			assertMatch()
		}
		// check that the DB is in perfect health, and no discrepancies exist
		XCTAssertNoThrow( try await(synchronize()) == 0 )
	}
	
	func testBinarySearchValidity () {
		let pairs = (0..<2000).map { _ in
			(Date(timeIntervalSinceNow: Double.random(in: -100000...1000000)), (100000...999999).randomElement()!)
		}
		let indexer = { (pair: (Date, Int)) in String(format: "%08X", UInt32(pair.0.timeIntervalSince1970)) + String(pair.1) }
		var sorted = [String]()
		for pair in pairs {
			let sID = indexer(pair)
			let index = sorted.binarySearch(comparing: { $0 }, with: sID)
			if sorted.indices.contains(index) {
				if sorted[index] == sID {
					XCTFail()
					break
				} else {
					sorted.insert(sID, at: index)
				}
			} else {
				sorted.append(sID)
			}
		}
		let newSorted = pairs.map (indexer).sorted()
		XCTAssertEqual(sorted, newSorted)
	}
	
	func assertMatch () {
		var ops = 10
		while ops > 0 {
			XCTAssertNoThrow(ops = try await(sheet.operationsLeft()))
			usleep(100*1000)
		}
		
		XCTAssertNoThrow(
			try await(
				sheet.read(sheet: sheetTitle)
				.then(on: .global()) {
					let rows = [ ActivePhoneCall.header ] + self.db.map { $0.row() }
					XCTAssertEqual(rows.count, $0.values?.count)
					XCTAssertEqual(rows, $0.values)
					XCTAssertEqual(Set(self.db.map { $0.dbKey() }).count, self.db.count)
				}
			)
		)
	}
	
}
extension IndexedSheetTests: AtomicSheetDelegate {
	func operationDidFail(_ sheet: String, operation: Sheet.Operation, error: Error) {
		
	}
	func uploadWillBegin(_ sheet: String, operations: [Sheet.Operation]) {
		print ("will upload \(operations.count) operations")
	}
	func uploadDidSucceed(_ sheet: String, operations: [Sheet.Operation]) {
		print ("uploaded successfully \(operations.count) operations")
	}
	func uploadDidFail(_ sheet: String, operations: [Sheet.Operation], error: Error) {
		print ("failed \(operations.count) operations, error: \(error)")
	}
}
