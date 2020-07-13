import XCTest
import NIO
import AsyncHTTPClient
@testable import Queenfisher

final class AuthenticationTests: XCTestCase {
	
	static var globalAuth: AuthenticationFactory?
	
	var serviceAcc: GoogleServiceAccount!
	var oauth: GoogleOAuthClient!

	static func gen () -> AuthenticationTests {
		.init()//.init(name: "auth", testClosure: {_ in })
	}

	func testGoogleScope () {
		var scope: GoogleScope = .sheets + .mailFullAccess + .calender
		XCTAssertTrue(scope.contains(.sheets))
		XCTAssertTrue(scope.contains(.mailFullAccess))
		
		scope += .mailCompose
		XCTAssertTrue(scope.contains(.mailCompose))
		XCTAssertFalse(scope.contains(.mailCompose + .storageRead))
		XCTAssertTrue(scope.containsAny(.mailCompose + .storageRead))
		
		let encoder = JSONEncoder()
		
		//print (scope.rawValue)

		var data = Data ()
		XCTAssertNoThrow(data = try encoder.encode([scope])) 
		
		let decoder = JSONDecoder()
		var scope2: GoogleScope = .sheets
		XCTAssertNoThrow(scope2 = try decoder.decode([GoogleScope].self, from: data)[0])
		
		XCTAssertEqual(scope, scope2)
	}
	
	func loadOAuth () {
		loadOAuthClient()
		guard let oauth = oauth else {
			return
		}
		print(oauth.authUrl(for: .mailAll + .sheets))
		print("login here and return code: ")
		let code = readLine(strippingNewline: true)!
		
		let future = oauth.fetchToken(fromCode: code, client: getHttpClient())
			.map { (token) -> Void in
				print(token)
				//try! JSONEncoder().encode(token).write(to: testApiKeyUrl)
			}
		XCTAssertNoThrow(try future.wait())
	}
	func testServiceAccountAuth () {
		loadServiceAccount()
		if serviceAcc != nil {
			XCTAssertNoThrow( try serviceAcc.fetchToken(for: .sheets + .mailFullAccess, client: getHttpClient()).wait() )
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
		if let global = AuthenticationTests.globalAuth, global.scope.containsAny(scope) {
			return global
		}
		var factory: AuthenticationFactory?
		if FileManager.default.fileExists(atPath: testApiKeyUrl.path) {
			loadOAuthClient()
			if oauth != nil {
				_ = FileManager.default.contents(atPath: testApiKeyUrl.path)?.debugDescription ?? ""
				do {
					factory = try oauth.factory(usingAccessToken: .loading(fromJSONAt: testApiKeyUrl))
					if factory!.scope.containsAny (scope) {
						AuthenticationTests.globalAuth = factory
						return factory!
					}					
				} catch let error {
					print ("error in getting OAuth client: \(error)")
				}
			}
		}
		
		print("could not get oauth, loading service account")
		loadServiceAccount()
		factory = serviceAcc?.factory(forScope: scope)
		AuthenticationTests.globalAuth = factory
		return factory
	}
}
