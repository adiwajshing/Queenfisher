import XCTest
import Promises
@testable import QueenfisherUltra

final class AuthenticationTests: XCTestCase {
	
	var acc: GoogleServiceAccount!
	var oauth: GoogleOAuthClient!
	var apiKey: GoogleAPIKey!
	
	func testOAuth () {
		XCTAssertNoThrow(try loadOAuthClient())
		
		guard let oauth = oauth else {
			return
		}
		
		print(oauth.authUrl(for: .mailFullAccess))
		
		print("login here and return code: ")
		let code = readLine(strippingNewline: true)!
		
		XCTAssertNoThrow(
			try await(
				oauth.apiKey(from: code)
				.then(on: .global()) { print($0) }
				.then(on: .global()) { try JSONEncoder().encode($0).write(to: testApiKeyUrl) }
			)
		)
	}
	func testServiceAccountAuth () {
		print (FileManager.default.contents(atPath: testCredsFileUrl.path)?.description ?? "")
		XCTAssertNoThrow(try loadServiceAccount(scope: .sheets))
		XCTAssertNotNil(acc)
		XCTAssertNotNil(acc.apiKeys[.sheets])
	}
	func loadServiceAccount (scope: GoogleScope) throws {
		print (FileManager.default.contents(atPath: testCredsFileUrl.path)?.debugDescription ?? "")
		acc = try .loading(fromJSONAt: testCredsFileUrl)
		if let acc = acc {
			_ = try await(acc.authenticate(scope: scope))
		}
	}
	func loadOAuthClient () throws {
		print (FileManager.default.contents(atPath: testClientFileUrl.path)?.description ?? "")
		XCTAssertNoThrow(oauth = try .loading(fromJSONAt: testClientFileUrl))
		
		if FileManager.default.fileExists(atPath: testApiKeyUrl.path) {
			_ = FileManager.default.contents(atPath: testApiKeyUrl.path)?.debugDescription ?? ""
			XCTAssertNoThrow(try oauth.setFactoryKey(.loading(fromJSONAt: testApiKeyUrl)))
		}
	}
}
