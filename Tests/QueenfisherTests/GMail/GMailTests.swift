import XCTest
import Promises
@testable import Queenfisher

final class GMailTests: XCTestCase {
	var gmail: GMail!
	var profile: GMail.Profile!
	let auth = AuthenticationTests()
	
	let queue: DispatchQueue = .global()
	
	override func setUp() {
		let auth = AuthenticationTests().getFactory(for: .mailCompose + .mailRead + .mailModify)!
		gmail = .init(auth: auth)
		XCTAssertNoThrow(profile = try await(gmail.profile()))
	}
	override func tearDown() {
		gmail = nil
	}
	/// Sends an email to oneself
	func sendMessage (text: String, subject: String = "Hello", attachments: [String] = []) -> Promise<GMail.Message> {
		let urls = attachments.map { testAttachmentsUrl.appendingPathComponent($0) }
		let message: GMail.Message = .init(from: .namedEmail("Me", profile.emailAddress),
										   to: [ .namedEmail("Myself & I", profile.emailAddress) ],
										   subject: subject,
										   text: text,
										   attachments: urls.map { try! .attachment(fileAt: $0) })
		return gmail.send(message: message)
	}
	/// gets the first unread message in the inbox or creates one lol
	func getAnUnreadMessage () -> Promise<GMail.Message> {
		gmail.listUnread()
		.then(on: queue) { m -> Promise<GMail.Message> in
			if let messages = m.messages {
				return self.gmail.get(id: messages.first!.id)
			} else {
				print ("creating unread message")
				return self.sendMessage(text: "this is a test")
					.then(on: self.queue) { _ in self.gmail.list(q: "is:unread", maxResults: 1) }
					.then(on: self.queue) { self.gmail.get(id: $0.messages!.first!.id) }
			}
		}
	}
	func testProfile () {
		if profile != nil {
			print("Oh hello " + profile.emailAddress)
		}
	}
	func testMarkReadMessage () {
		let promise = getAnUnreadMessage()
			.then(on: queue) { self.gmail.markRead(id: $0.id) }
			.then(on: queue) { self.gmail.get(id: $0.id) }
			.then(on: queue) { XCTAssertFalse( $0.labelIds.contains("UNREAD") ) }
		XCTAssertNoThrow( try await(promise) )
	}
	func testMessages () {
		let promise = gmail.list()
			.then(on: queue) { print ("\($0.resultSizeEstimate) messages loaded") }
			.then(on: queue) { self.gmail.listUnread() }
			.then(on: queue) { print ("\($0.resultSizeEstimate) unread messages loaded") }
		
		XCTAssertNoThrow( try await(promise) )
	}
	func testTrash () {
		var id: String = ""
		let promise = sendMessage(text: "some <i>HTML</i> text here")
			.then(on: queue) { _ in self.gmail.list() }
			.then(on: queue) { id = $0.messages!.first!.id }
			.then(on: queue) { self.gmail.trash(id: id) }
			.then(on: queue) { _ in self.gmail.list() }
			.then(on: queue) { XCTAssertFalse($0.messages!.contains(where: {$0.id == id})) }
		
		XCTAssertNoThrow( try await(promise) )
	}
	func testParseMessage () {
		var id: String = ""
		let promise = gmail.list()
			.then(on: queue) { m -> Promise<Void> in
				if let messages = m.messages {
					id = messages[0].id
					return .init(())
				} else {
					return self.sendMessage(text: "This is a message lol", subject: "Test")
						.then(on: self.queue) { id = $0.id }
				}
			}
			.then(on: queue) { self.gmail.get(id: id, format: .full) }
			.then(on: queue) {
				XCTAssertNotNil($0.payload)
				if $0.payload?.body == nil {
					XCTAssertNotNil($0.payload?.parts)
					XCTAssertNotNil($0.payload?.parts?.first)
					XCTAssertNotNil($0.payload?.parts?.first?.body?.data)
				}
				XCTAssertNotNil($0.from)
				XCTAssertNotNil($0.to)
				print ("full message received & parsed correctly")
				return .init(())
			}
			.then(on: queue) { self.gmail.get(id: id, format: .raw) }
			.then(on: queue) {
				XCTAssertNotNil($0.raw)
				print ("raw message received & parsed correctly")
				return .init(())
			}
			.then(on: queue) { self.gmail.get(id: id, format: .metadata) }
			.then(on: queue) {
				XCTAssertNotNil($0.to)
				XCTAssertNotNil($0.subject)
				print ("metadata message received & parsed correctly")
			}
		
		XCTAssertNoThrow( try await(promise) )
	}
	func testReplyToMessage () {
		var ogMail: GMail.Message!
		let promise = sendMessage(text: "I am v <b>certain<b/> this email will get a reply",
								  subject: "Cool Subject",
								  attachments: ["meme.jpeg"])
			.then(on: queue) { ogMail = $0 }
			.then(on: queue) { self.gmail.get(id: ogMail.id, format: .metadata) }
			.delay(on: queue, 2)
			.then(on: queue) { self.gmail.send(message: GMail.Message(replyingTo: $0,
																	  fromMe: true,
																	  text: "Wow you were right, wow")!) }
			.then(on: queue) { XCTAssertEqual($0.threadId, ogMail.threadId) }
		XCTAssertNoThrow( try await(promise) )
	}
	func testSendMessage () {
		let subject = "This is a test mail with attachments"
		let promise = sendMessage(text: "I have gif for you. Look at <i>HTML<i/> <b>bold</b> text",
								  subject: subject,
								  attachments: ["meme.jpeg", "ma_gif.mp4"])
						.then(on: queue) { _ in self.gmail.list(q: "is:unread", maxResults: 1) }
						.then(on: queue) { self.gmail.get(id: $0.messages!.first!.id, format: .full) }
						.then(on: queue) {
							XCTAssertEqual($0.from?.email, self.profile.emailAddress)
							XCTAssertEqual($0.payload?.parts?.count, 3) // check all parts went
							XCTAssertEqual($0.subject, subject) // check subject went okay
						}
		XCTAssertNoThrow( try await(promise) )
		
	}
	func testMailFetch () {
		XCTAssertNoThrow(try await(getAnUnreadMessage()))
		
		var firstBatch: [GMail.Message]!
		let promise = Promise<Void>.pending()
		gmail.fetch(over: .seconds(20), q: "is:unread") { result in
			switch result {
			case .success(let messages):
				if let firstBatch = firstBatch {
					XCTAssertGreaterThan(messages.count, 0)
					for m in messages {
						XCTAssertFalse(firstBatch.contains { $0.id == m.id } )
					}
					promise.fulfill(())
				} else {
					XCTAssertGreaterThan(messages.count, 0)
					firstBatch = messages
					_ = self.sendMessage(text: "Some message to myself")
				}
				
				break
			case .failure(let error):
				promise.reject(error)
				break
			}
		}
		XCTAssertNoThrow( try await(promise) )
		
		gmail.stopFetch()
		XCTAssertNil(gmail.fetchTimer)
	}
}
