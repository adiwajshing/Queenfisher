import XCTest
import Promises
@testable import QueenfisherUltra

final class AuthenticationTests: XCTestCase {
	
	var serviceAcc: GoogleServiceAccount!
	var oauth: GoogleOAuthClient!
	
	let queue: DispatchQueue = .global()
	
	func testGoogleScope () {
		var scope: GoogleScope = .sheets + .mailFullAccess + .calender
		XCTAssertTrue(scope.contains(.sheets))
		XCTAssertTrue(scope.contains(.mailFullAccess))
		
		scope += .mailSend
		XCTAssertTrue(scope.contains(.mailSend))
		XCTAssertFalse(scope.contains(.mailSend + .storageRead))
		
		let encoder = JSONEncoder()
		let data = try! encoder.encode(scope)
		
		let decoder = JSONDecoder()
		let scope2 = try! decoder.decode(GoogleScope.self, from: data)
		
		XCTAssertEqual(scope, scope2)
	}
	
	func testOAuth () {
		loadOAuthClient()
		guard let oauth = oauth else {
			return
		}
		print(oauth.authUrl(for: .mailFullAccess + .sheets))
		print("login here and return code: ")
		let code = readLine(strippingNewline: true)!
		
		XCTAssertNoThrow(
			try await(
				oauth.fetchToken(fromCode: code)
				.then(on: queue) { print($0) }
				.then(on: queue) { try JSONEncoder().encode($0).write(to: testApiKeyUrl) }
			)
		)
	}
	func testServiceAccountAuth () {
		loadServiceAccount()
		if serviceAcc != nil {
			XCTAssertNoThrow( try await(serviceAcc.fetchToken(for: .sheets + .mailFullAccess)) )
		}
	}
	func loadServiceAccount () {
		print (FileManager.default.contents(atPath: testCredsFileUrl.path)?.debugDescription ?? "")
		XCTAssertNoThrow(serviceAcc = try .loading(fromJSONAt: testCredsFileUrl))
	}
	func loadOAuthClient () {
		print (FileManager.default.contents(atPath: testClientFileUrl.path)?.description ?? "")
		XCTAssertNoThrow(oauth = try .loading(fromJSONAt: testClientFileUrl))
	}
	func getFactory (for scope: GoogleScope) -> AuthenticationFactory? {
		var factory: AuthenticationFactory?
		if FileManager.default.fileExists(atPath: testApiKeyUrl.path) {
			loadOAuthClient()
			if oauth != nil {
				_ = FileManager.default.contents(atPath: testApiKeyUrl.path)?.debugDescription ?? ""
				do {
					factory = try oauth.factory(for: scope,
												usingAccessToken: .loading(fromJSONAt: testApiKeyUrl))
					return factory!
				} catch {
					
				}
			}
		}
		
		print("could not get oauth, loading service account")
		loadServiceAccount()
		factory = serviceAcc?.factory(for: scope)
		return factory
	}
	
}
