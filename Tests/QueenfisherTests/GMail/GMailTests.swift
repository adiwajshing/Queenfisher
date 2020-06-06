import XCTest
import NIO
@testable import Queenfisher

final class GMailTests: XCTestCase {
	var gmail: GMail!
	var profile: GMail.Profile!
	
	override func setUp() {
		let auth = AuthenticationTests.gen().getFactory(for: .mailCompose + .mailRead + .mailModify)!
		gmail = .init(auth: auth, client: getHttpClient())
		XCTAssertNoThrow(profile = try gmail.profile().wait())
	}
	override func tearDown() {
		gmail = nil
	}
	/// Sends an email to oneself
	func sendMessage (text: String, subject: String = "Hello", attachments: [String] = []) -> EventLoopFuture<GMail.Message> {
		let urls = attachments.map { testAttachmentsUrl.appendingPathComponent($0) }
		let message: GMail.Message = .init(from: .namedEmail("Me", profile.emailAddress),
										   to: [ .namedEmail("Myself & I", profile.emailAddress) ],
										   subject: subject,
										   text: text,
										   attachments: urls.map { try! .attachment(fileAt: $0) })
		return gmail.send(message: message)
	}
	/// gets the first unread message in the inbox or creates one lol
	func getAnUnreadMessage () -> EventLoopFuture<GMail.Message> {
		gmail.listUnread()
		.flatMapThrowing { m -> EventLoopFuture<GMail.Message> in
			if let messages = m.messages {
				return self.gmail.get(id: messages.first!.id)
			} else {
				print ("creating unread message")
				return self.sendMessage(text: "this is a test")
			}
		}
	}
	func testProfile () {
		if profile != nil {
			print("Oh hello " + profile.emailAddress)
		}
	}
	func testMarkReadMessage () {
		let future = getAnUnreadMessage()
			.flatMapThrowing { self.gmail.markRead(id: $0.id) }
			.flatMapThrowing { self.gmail.get(id: $0.id) }
			.map { XCTAssertFalse( $0.labelIds.contains("UNREAD") ) }
		XCTAssertNoThrow( try future.wait() )
	}
	func testMessages () {
		let future = gmail.list()
			.map { print ("\($0.resultSizeEstimate) messages loaded") }
			.flatMapThrowing { self.gmail.listUnread() }
			.map { print ("\($0.resultSizeEstimate) unread messages loaded") }
		XCTAssertNoThrow(try future.wait())
	}
	func testTrash () {
		var id: String = ""
		let future = sendMessage(text: "some <i>HTML</i> text here")
			.flatMapThrowing { _ in self.gmail.list() }
			.map { id = $0.messages!.first!.id }
			.flatMapThrowing { self.gmail.trash(id: id) }
			.flatMapThrowing { _ in self.gmail.list() }
			.map { XCTAssertFalse($0.messages!.contains(where: {$0.id == id})) }
		
		XCTAssertNoThrow( try future.wait() )
	}
	func testParseMessage () {
		var id: String = ""
		let future = gmail.list()
			.flatMap { m in
				if let messages = m.messages {
					id = messages[0].id
					return self.gmail.client.eventLoopGroup.next().makeSucceededFuture(())
				} else {
					return self.sendMessage(text: "This is a message lol", subject: "Test").map { id = $0.id }
				}
			}
			.flatMap { self.gmail.get(id: id, format: .full) }
			.map {
				XCTAssertNotNil($0.payload)
				if $0.payload?.body == nil {
					XCTAssertNotNil($0.payload?.parts)
					XCTAssertNotNil($0.payload?.parts?.first)
					XCTAssertNotNil($0.payload?.parts?.first?.body?.data)
				}
				XCTAssertNotNil($0.from)
				XCTAssertNotNil($0.to)
				print ("full message received & parsed correctly")
			}
			.flatMap { self.gmail.get(id: id, format: .raw) }
			.map {
				XCTAssertNotNil($0.raw)
				print ("raw message received & parsed correctly")
			}
			.flatMap { self.gmail.get(id: id, format: .metadata) }
			.map {
				XCTAssertNotNil($0.to)
				XCTAssertNotNil($0.subject)
				print ("metadata message received & parsed correctly")
			}
		XCTAssertNoThrow( try future.wait() )
	}
	func testReplyToMessage () {
		var ogMail: GMail.Message!
		let promise = sendMessage(text: "I am v <b>certain<b/> this email will get a reply",
								  subject: "Cool Subject",
								  attachments: ["meme.jpeg"])
			.map { ogMail = $0 }
			.flatMap { self.gmail.get(id: ogMail.id, format: .metadata) }
			.delay(.seconds(3))
			.flatMap { self.gmail.send(message: GMail.Message(replyingTo: $0,
																	  fromMe: true,
																	  text: "Wow you were right, wow")!) }
			.map { XCTAssertEqual($0.threadId, ogMail.threadId) }
		XCTAssertNoThrow( try promise.wait() )
	}
	func testSendMessage () {
		let subject = "This is a test mail with attachments"
		let promise = sendMessage(text: "I have gif for you. Look at <i>HTML<i/> <b>bold</b> text",
								  subject: subject,
								  attachments: ["meme.jpeg", "ma_gif.mp4"])
						.flatMap { _ in self.gmail.list(q: "is:unread", maxResults: 1) }
						.flatMap { self.gmail.get(id: $0.messages!.first!.id, format: .full) }
						.map {
							XCTAssertEqual($0.from?.email, self.profile.emailAddress)
							XCTAssertEqual($0.payload?.parts?.count, 3) // check all parts went
							XCTAssertEqual($0.subject, subject) // check subject went okay
						}
		XCTAssertNoThrow( try promise.wait() )
		
	}
	func testMailFetch () {
		XCTAssertNoThrow(try getAnUnreadMessage().wait())
		
		var firstBatch: [GMail.Message]!
		let promise = gmail.client.eventLoopGroup.next().makePromise(of: Void.self)
		gmail.fetch(over: .seconds(20), q: "is:unread") { result in
			switch result {
			case .success(let messages):
				if let firstBatch = firstBatch {
					XCTAssertGreaterThan(messages.count, 0)
					for m in messages {
						XCTAssertFalse(firstBatch.contains { $0.id == m.id } )
					}
					promise.succeed(())
				} else {
					XCTAssertGreaterThan(messages.count, 0)
					firstBatch = messages
					_ = self.sendMessage(text: "Some message to myself")
				}
				
				break
			case .failure(let error):
				promise.fail(error)
				break
			}
		}
		XCTAssertNoThrow( try promise.futureResult.wait() )
		
		gmail.stopFetch()
		XCTAssertNil(gmail.fetchTimer)
	}
}
