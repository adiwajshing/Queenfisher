//
//  GMail.swift
//  
//
//  Created by Adhiraj Singh on 5/20/20.
//

import Foundation
import NIO
import NIOHTTP1
import AsyncHTTPClient

let gmailApiUrl = URL(string: "https://www.googleapis.com/gmail/v1/")!

/// Class to access a GMail account
public class GMail {
	public let auth: Authenticator
	public let userId: String
	public let client: HTTPClient
	
	var fetchTimer: DispatchSourceTimer!
	var isFetching = false
	var fetchQuery = ""
	let serialQueue: DispatchQueue = .init(label: "serial-gmail", attributes: [])
	internal(set) public var lastFetchDate = Date(timeIntervalSince1970: 0)
	
	lazy var url: URL = { gmailApiUrl.appendingPathComponent("users").appendingPathComponent(userId) }()
	
	public init (auth: Authenticator, email userId: String = "me", client: HTTPClient) {
		self.auth = auth
		self.userId = userId
		self.client = client
	}
	/// Marks the specific message as read (required scope: .mailModify or .mailFullAccess)
	/// - Parameter id: The id of the specified message
	/// - Returns: The modified message in the `minimal` format
	public func markRead (id: String) -> EventLoopFuture<Message> {
		modify(id: id, removingLabelIds: ["UNREAD"])
	}
	/**
	Modifies the labels on the specified message (required scope: .mailModify or .mailFullAccess)
	- Parameter id: The id of the specified message
	- Parameter addingLabelIds: A list of IDs of labels to add to this message
	- Parameter removingLabelIds: A list of IDs of labels to remove from this message
	- Returns: The modified message in the `minimal` format
	*/
	public func modify (id: String, addingLabelIds adds: [String] = [], removingLabelIds removes: [String] = []) -> EventLoopFuture<Message> {
		let url = self.url
					.appendingPathComponent("messages")
					.appendingPathComponent(id)
					.appendingPathComponent("modify")
		return authRequest(on: url,
						   body: ModificationRequest(addLabelIds: adds, removeLabelIds: removes),
						   method: .POST,
						   scope: .mailModify + .mailFullAccess)
	}
	/**
	Moves the specified message to the trash (required scope: .mailModify or .mailFullAccess)
	- Parameter id: The id of the specified message
	- Returns: The trashed message in the `minimal` format
	*/
	public func trash (id: String) -> EventLoopFuture<Message> {
		authRequest(on: url
						.appendingPathComponent("messages")
						.appendingPathComponent(id)
						.appendingPathComponent("trash"),
					method: .POST,
					scope: .mailModify + .mailFullAccess)
	}
	/**
	Gets the specified message (required scope: .mailRead or .mailFullAccess)
	- Parameter id: The id of the specified message
	- Parameter format: The format to return the message in
	- Parameter metadataHeaders: A list of metadata headers to include. When given and format is METADATA, only include headers specified
	- Returns: The message in the specified format
	*/
	public func get (id: String, format: MessageFormat = .full, metadataHeaders: [String] = []) -> EventLoopFuture<Message> {
		authRequest(on: url.appendingPathComponent("messages").appendingPathComponent(id),
					body: MessageQuery(format: format,
									   metadataHeaders: metadataHeaders.count > 0 ? metadataHeaders.joined(separator: ",") : nil),
					method: .GET,
					scope: .mailRead + .mailFullAccess)
	}
	/**
	Sends the specified message to the recipients (required scope: .mailCompose or .mailFullAccess)
	- Parameter message: the message to send
	- Returns: Metadata of the message in the `minimal` format
	*/
	public func send (message: Message) -> EventLoopFuture<Message> {
		authRequest(on: url.appendingPathComponent("messages").appendingPathComponent("send"),
					body: EncodedMail(raw: message.raw!,
									  threadId: message.threadId.isEmpty ? "" : message.threadId),
					method: .POST,
					scope: .mailCompose)
	}
	/// Lists all the unread messages in the user's mailbox (required scope: .mailRead or .mailFullAccess)
	public func listUnread () -> EventLoopFuture<Messages> {
		list(q: "is:unread")
	}
	/// Lists all messages in the query (required scope: .mailRead or .mailFullAccess)
	public func listAll (includeSpamTrash: Bool = false, q: String? = nil, pageToken: String? = nil) -> EventLoopFuture<Messages> {
		var messages: Messages!
		return list(includeSpamTrash: includeSpamTrash, q: q, pageToken: pageToken)
		.flatMap { m -> EventLoopFuture<Messages> in
			messages = m
			if let nextToken = m.nextPageToken {
				return self.listAll(includeSpamTrash: includeSpamTrash,
									q: q,
									pageToken: nextToken)
			} else {
				return self.client.eventLoopGroup.next()
					.makeSucceededFuture(Messages(messages: nil,
												  nextPageToken: nil,
												  resultSizeEstimate: 0))
			}
		}
		.map { m -> Messages in
			if var ms = m.messages {
				ms += m.messages ?? []
				return Messages(messages: ms, nextPageToken: nil, resultSizeEstimate: ms.count)
			}
			return messages
		}
	}
	/**
	Lists the messages in the user's mailbox (required scope: .mailRead or .mailFullAccess)
	- Parameter includeSpamTrash: Include messages from `SPAM` and `TRASH` in the results
	- Parameter q: Only return messages matching the specified query. Supports the same query format as the Gmail search box. For example, "from:someuser@example.com rfc822msgid:<somemsgid@example.com> is:unread"
	- Parameter maxResults: Maximum number of messages to return
	- Parameter pageToken: Page token to retrieve a specific page of results in the list
	*/
	public func list (includeSpamTrash: Bool = false, q: String? = nil, maxResults: UInt? = nil, pageToken: String? = nil) -> EventLoopFuture<Messages> {
		authRequest(on: url.appendingPathComponent("messages"),
					body: MessagesQuery(includeSpamTrash: includeSpamTrash,
										q: q,
										maxResults: maxResults,
										pageToken: pageToken),
					method: .GET,
					scope: .mailRead + .mailFullAccess)
	}
	
	public func profile () -> EventLoopFuture<Profile> {
		authRequest(on: self.url.appendingPathComponent("profile"), method: .GET, scope: .mailAll)
	}
	/// Make an authenticated request to the given URL
	public func authRequest<E: Encodable, O: Decodable> (on url: URL, body: E, method: HTTPMethod, scope: GoogleScope) -> EventLoopFuture<O> {
		auth.authenticationHeader(scope: scope, client: client)
		.flatMapThrowing { try self.client.execute(url: url, headers: [$0], body: body, method: method, errorType: ErrorResponse.self) }
	}
	/// Make an authenticated request to the given URL
	public func authRequest<O: Decodable> (on url: URL, method: HTTPMethod, scope: GoogleScope) -> EventLoopFuture<O> {
		auth.authenticationHeader(scope: scope, client: client)
		.flatMapThrowing { try self.client.execute(url: url, headers: [$0], method: method, errorType: ErrorResponse.self) }
	}
	
	public enum MessageFormat: String, Codable {
		/// Returns the full email message data with body content parsed in the payload field
		case full = "full"
		/// Returns only email message ID, labels, and email headers.
		case metadata = "metadata"
		/// Returns only email message ID and labels
		case minimal = "minimal"
		/// Returns the full email message data with body content in the raw field as a base64url encoded string
		case raw = "raw"
	}
	public struct Messages: Codable {
		public struct MessageMeta: Codable {
			public var id: String
			public var threadId: String
		}
		/// List of messages. Note that each message resource contains only an `id` and a `threadId`.
		/// Additional message details can be fetched using the messages.get method.
		public let messages: [MessageMeta]?
		/// Token to retrieve the next page of results in the list. (nil when its the last page)
		public let nextPageToken: String?
		/// Estimated total number of results.
		public let resultSizeEstimate: Int
	}
	public struct Profile: Codable {
		public var emailAddress: String
		public var messagesTotal: Int
		public var threadsTotal: Int
		public var historyId: String
	}
	
	// Internal structures to help in requests
	
	struct MessagesQuery: Codable {
		var includeSpamTrash: Bool
		var q: String?
		var maxResults: UInt?
		var pageToken: String?
	}
	struct MessageQuery: Codable {
		var format: MessageFormat
		var metadataHeaders: String?
	}
	struct EncodedMail: Codable {
		var raw: Data
		var threadId: String?
	}
	struct ModificationRequest: Codable {
		var addLabelIds: [String]
		var removeLabelIds: [String]
	}
}
