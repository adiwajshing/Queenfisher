import XCTest
import Promises
import Atomics
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
			try? auth.loadAuth()
		}
		if sheet == nil {
			sheet = .init(spreadsheetId: testSpreadsheetId,
							sheetTitle: testSheet,
							using: auth.acc!,
							syncInterval: .seconds(5),
							delegate: self)
		}
	}
	func testLoadSheet () {
		loadSheetIfRequired()
		XCTAssertNoThrow(_ = try await (sheet.get(timeout: 20)))
	}
	func testWriteHeader () {
		loadSheetIfRequired()
		sheet.operate(.set(.row(0), [ header ]))
		
		while sheet.operationQueue.syncPointee.count > 0 {
			usleep(100*1000)
		}
	}
	func testManyAppend () {
		loadSheetIfRequired()
		
		var rows = [header]
		
		sheet.operate(.clear)
		sheet.operate(.set(.row(0), [ header ]))
		
		for person in personsData {
			sheet.operate(.appendRows([person.row()]))
			rows.append(person.row())
		}
		waitAndMatch(rows: rows)
	}
	func testManyAppendAndInsert () {
		loadSheetIfRequired()
		//sheet.replaceSheetForEfficiency = false
		
		sheet.operate(.clear)
		sheet.operate(.set(.row(0), [ header ]))
		
		DispatchQueue.concurrentPerform(iterations: personsData.count, execute: { i in
			let person = self.personsData[i]
			sheet.operate(using: { rows in
				let index = rows.suffix(from: 1).binarySearch(where: {$0[2] > person.email ? 1 : -1})
				if index < rows.count {
					//print ( "\(rows.suffix(from: 1)[index][2]), \(person.email), \(rows.map {$0[2]} )" )
					let tIndex = max(0, index)
					return [ .insert(.rows, tIndex..<(tIndex+1)), .set(.row(tIndex), [person.row()]) ]
				} else {
					return [ .appendRows([person.row()]) ]
				}
				
			})
		})
		var rows = [header]
		rows.append(contentsOf: personsData.sorted(by: {$0.email < $1.email}).map { $0.row() })
		waitAndMatch(rows: rows)
	}
	func testManyDelete () {
		testManyAppendAndInsert()
		//sheet.replaceSheetForEfficiency = false
		
		let personCountToDelete = personsData.count/3
		DispatchQueue.concurrentPerform(iterations: personCountToDelete, execute: { i in
			let person = self.personsData[i]
			sheet.operate(using: { rows in
				let index = rows.suffix(from: 1).binarySearch(where: {
					if $0[2] == person.email {
						return 0
					}
					return $0[2] > person.email ? 1 : -1
				})
				return [ .delete(.rows, index..<(index+1)) ]
			})
		})
		
		var rows = [header]
		let persons = personsData.suffix(from: personCountToDelete).sorted(by: { $0.email < $1.email })
		rows.append(contentsOf: persons.map { $0.row() } )
		
		waitAndMatch(rows: rows)
	}
	func waitAndMatch (rows: [[String]]) {
		while !sheet.isSheetLoaded || sheet.operationQueue.syncPointee.count > 0 {
			usleep(100*1000)
		}
		
		XCTAssertNoThrow(
			try await(try sheet.spreadsheet.read(sheet: testSheet)
			.then(on: .global()) {
				XCTAssertEqual(rows.count, $0.values!.count)
				for i in rows.indices {
					XCTAssertEqual(rows[i], $0.values?[i])
				}
			})
		)
	}
}

extension AtomicSheetTests: AtomicSheetDelegate {
	
	func uploadWillBegin(_ operations: [SheetOperation]) {
		print ("will upload \(operations.count) operations")
	}
	func uploadDidSucceed(_ operations: [SheetOperation]) {
		print ("uploaded successfully \(operations.count) operations")
	}
	func uploadDidFail(_ operations: [SheetOperation], error: Error) {
		print ("failed \(operations.count) operations, error: \(error)")
	}
	
}
extension Collection {
    /// Finds such index N that predicate is true for all elements up to
    /// but not including the index N, and is false for all elements
    /// starting with index N.
    /// Behavior is undefined if there is no such N.
    func binarySearch(where predicate: (Element) -> Int) -> Index {
        var low = startIndex
        var high = endIndex
        while low != high {
            let mid = index(low, offsetBy: distance(from: low, to: high)/2)
			let r = predicate(self[mid])
            if r < 0 {
                low = index(after: mid)
            } else if r > 0 {
                high = mid
			} else {
				low = mid
				break
			}
        }
		return low
    }
}
