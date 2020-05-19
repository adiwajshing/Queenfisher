import XCTest
import Promises
@testable import QueenfisherUltra

final class AuthenticationTests: XCTestCase {
	
	var acc: GoogleServiceAccount!
	
	func testServiceAccountAuth () {
		print (FileManager.default.contents(atPath: testCredsFileUrl.path)?.description ?? "")
		XCTAssertNoThrow(acc = try .loading(fromJSONAt: testCredsFileUrl))
		XCTAssertNotNil(acc)
		if let acc = acc {
			XCTAssertNoThrow(try await(acc.authenticate(scope: .sheets)))
			XCTAssertNotNil(acc.apiKeys[.sheets])
		}
	}
	func loadAuth () throws {
		print (FileManager.default.contents(atPath: testCredsFileUrl.path)?.debugDescription ?? "")
		acc = try .loading(fromJSONAt: testCredsFileUrl)
		if let acc = acc {
			_ = try await(acc.authenticate(scope: .sheets))
		}
	}
}
