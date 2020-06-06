import XCTest
import NIO
@testable import Queenfisher

final class IndexedSheetTests: XCTestCase {
	
	var db = (1..<100).map { _ in ActivePhoneCall.random() }.sorted()
	let sheetTitle = ActivePhoneCall.sheetTitle
	
	var sheet: IndexedSheet<String>!
	let queue: DispatchQueue = .init(label: "serial", attributes: [])
	
	override func setUp() {
		let auth = AuthenticationTests.new().getFactory(for: .sheets)!
		sheet = .init(spreadsheetId: testSpreadsheetId,
					  sheetTitle: sheetTitle,
					  using: auth,
					  header: ActivePhoneCall.header,
					  indexer: ActivePhoneCall.indexer,
					  client: getHttpClient(),
					  delegate: self)
	}
	override func tearDown() {
		sheet = nil
	}
	
	func newDB () {
		db = db.map { _ in ActivePhoneCall.random() }.sorted()
	}
	func testLoadSheet () {
		XCTAssertNoThrow(_ = try sheet.get().map { print($0) }.wait() )
	}
	func synchronize () -> EventLoopFuture<Int> {
		sheet.synchronize {
			let ev = self.sheet.client.eventLoopGroup.next()
			let task = ev.scheduleTask(in: .seconds(3)) { self.db.map { $0.row() } }
			return task.futureResult
		}
	}
	func testSynchronize () {
		// check that it synchronizes correctly even when the sheet is empty & when the DB is completely different
		for _ in 0..<2 {
			newDB()
			XCTAssertNoThrow(try synchronize().wait())
			assertMatch()
		}
	}
	
	func executeManyOperations () {
		queue.sync {
			for _ in 0..<100 {
				let op = (0..<5).randomElement()!
				switch op {
				case 0:
					let index = db.indices.randomElement()!
					db[index].toNumber = String ((1000000000...9999999999).randomElement()!)
					_ = sheet.update(values: db[index].toNumber, for: db[index].dbKey(), offset: 2)
					break
				case 1:
					let index = db.indices.randomElement()!
					let row = db[index].row()
					_ = sheet.delete(row: row)
					db.remove(at: index)
					break
				case 2:
					
					break
				default:
					let p = ActivePhoneCall.random()
					_ = sheet.place(row: p.row())
					if let index = db.firstIndex(where: { $0 > p }) {
						db.insert(p, at: index)
					} else {
						db.append(p)
					}
					break
				}
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
		XCTAssertNoThrow( try synchronize().wait() == 0 )
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
			XCTAssertNoThrow(ops = try sheet.operationsLeft().wait())
			usleep(100*1000)
		}
		let future = sheet.read(sheet: sheetTitle)
		future.whenSuccess {
			let rows = [ ActivePhoneCall.header ] + self.db.map { $0.row() }
			XCTAssertEqual(rows.count, $0.values?.count)
			XCTAssertEqual(rows, $0.values)
			XCTAssertEqual(Set(self.db.map { $0.dbKey() }).count, self.db.count)
		}
		XCTAssertNoThrow( try future.wait() )
	}
	
}
extension IndexedSheetTests: AtomicSheetDelegate {
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
