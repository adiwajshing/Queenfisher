import XCTest
import Promises
@testable import QueenfisherUltra

final class AtomicSheetTests: XCTestCase {
	
	struct Person {
		let dob: Date
		let id: UInt64
		let email: String
		let name: String
		
		func row () -> [String] {
			let formatter = DateFormatter()
			formatter.dateFormat = "dd/MM/YYYY"
			return [formatter.string(from: dob), String(id), email, name]
		}
		
		static func random () -> Person {
			let range = (1000..<100000000).randomElement()!
			let dob: Date = .init(timeIntervalSince1970: Double(range))
			let id: UInt64 = (100000000...9999999999).randomElement()!
			
			let firstName = ["Alice", "Bob", "Mallory", "Eve", "Jeff"].randomElement()!
			let lastName = ["Alice", "Bob", "Mallory", "Eve", "Singh"].randomElement()!
			let email: String = "\(firstName).\(lastName)_\(id)@mail.com"
			let name: String = "\(firstName) \(lastName)"
			return .init(dob: dob, id: id, email: email, name: name)
		}
	}
	
	let personsData = (0..<300).map { _ in Person.random() }
	let header = [ "DOB", "ID", "Email", "Name" ]
	
	let testSheet = "AtomicSheetTest"
	
	var sheet: AtomicSheet<GoogleServiceAccount>!
	let auth = AuthenticationTests()
	
	func loadSheetIfRequired () {
		if auth.acc == nil {
			try? auth.loadServiceAccount(scope: .sheets)
		}
		if sheet == nil {
			sheet = .init(spreadsheetId: testSpreadsheetId, sheetTitle: testSheet, using: auth.acc!, delegate: self)
		}
	}
	func testLoadSheet () {
		loadSheetIfRequired()
		XCTAssertNoThrow(_ = try await (sheet.get().then(on: .global()) { print($0) } ))
	}
	func testWriteHeader () {
		loadSheetIfRequired()
		_ = sheet.operate {
			try $0.clear()
			try $0.set(rows: [self.header], at: .row(0))
		}
		waitAndMatch(rows: [header])
	}
	func testManyAppend () {
		loadSheetIfRequired()
		
		var rows = [header]
		rows += personsData.map { $0.row() }
		
		_ = sheet.operate {
			try $0.clear()
			try $0.set(rows: [self.header], at: .row(0))
			
			for person in self.personsData {
				try $0.append(rows: [person.row()])
			}
		}
		waitAndMatch(rows: rows)
	}
	func testManyAppendAndInsert () {
		loadSheetIfRequired()
		
		_ = sheet.operate {
			try $0.clear()
			try $0.set(rows: [self.header], at: .row(0))
		}
		DispatchQueue.concurrentPerform(iterations: personsData.count, execute: { i in
			let person = self.personsData[i]
			_ = sheet.operate(using: { sheet in
				let actual = sheet.data.suffix(from: 1)
				let index = actual.binarySearch(comparing: {$0[2]}, with: person.email)
				if actual.indices.contains(index) {
					try sheet.insert(dimension: .rows, range: index..<(index+1))
					try sheet.set(rows: [person.row()], at: .row(index))
				} else {
					try sheet.append(rows: [person.row()])
				}
			})
		})
		var rows = [header]
		rows.append(contentsOf: personsData.sorted(by: {$0.email < $1.email}).map { $0.row() })
		waitAndMatch(rows: rows)
	}
	func testManyDelete () {
		testManyAppendAndInsert()
		
		let personCountToDelete = personsData.count/3
		DispatchQueue.concurrentPerform(iterations: personCountToDelete, execute: { i in
			let person = self.personsData[i]
			_ = sheet.operate(using: { sheet in
				let index = sheet.data.suffix(from: 1).binarySearch(comparing: {$0[2]}, with: person.email)
				try sheet.delete(dimension: .rows, range: index..<(index+1))
			})
		})
		
		var rows = [header]
		let persons = personsData.suffix(from: personCountToDelete).sorted(by: { $0.email < $1.email })
		rows.append(contentsOf: persons.map { $0.row() } )
		
		waitAndMatch(rows: rows)
	}
	func testMove () {
		testManyAppendAndInsert()
		
		let start = personsData.count-15
		let end = start+5
		_ = sheet.operate {
			try $0.move(dimension: .rows, range: start..<end, to: 1)
			try $0.move(dimension: .rows, range: start..<end, to: end+5)
		}
		.catch { print("error: \($0)") }
		
		let rows = try! await(sheet.get())
		waitAndMatch(rows: rows)
	}
	func waitAndMatch (rows: [[String]]) {
		while try! await(sheet.operationsLeft()) > 0 {
			usleep(100*1000)
		}
		
		XCTAssertNoThrow(
			try await(
				try sheet.read(sheet: testSheet)
				.then(on: .global()) {
					XCTAssertEqual(rows.count, $0.values!.count)
					for i in rows.indices {
						XCTAssertEqual(rows[i], $0.values?[i])
					}
				}
			)
		)
	}
}

extension AtomicSheetTests: AtomicSheetDelegate {
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
