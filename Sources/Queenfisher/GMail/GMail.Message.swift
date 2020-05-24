//
//  GMail.Message.swift
//  
//
//  Created by Adhiraj Singh on 5/21/20.
//

import Foundation

public extension GMail {
	/// An E-Mail Message
	struct Message: Codable {
		/// A header
		public struct Header: Codable {
			public var name: String
			public var value: String
		}
		/// Body of a part of an email
		public struct Body: Codable {
			public var size: Int
			public var attachmentId: String? = nil
			public var data: Data? = nil
			/// Decode encoded data as a string, returns empty if an error occurs
			public func text () -> String {
				String(data: data ?? Data(), encoding: .utf8) ?? ""
			}
		}
		/// Actual structure of an email
		public struct Payload: Codable {
			/// The immutable ID of the message part.
			public var partId: String?
			/// The MIME type of the message part.
			public var mimeType: String
			/// The filename of the attachment. Only present if this message part represents an attachment.
			public var filename: String?
			/// List of headers on this message part.
			/// For the top-level message part, representing the entire message payload,
			/// it will contain the standard RFC 2822 email headers such as `To`, `From`, and `Subject`.
			public var headers: [Header]
			/// The message part body for this part, which may be empty for container MIME message parts.
			public var body: Body?
			/// The child MIME message parts of this part. This only applies to container MIME message parts, for example `multipart/*`.
			public var parts: [Payload]?
		}
		/// The immutable ID of the message.
		public let id: String
		/// The ID of the thread the message belongs to.
		public let threadId: String
		/// List of IDs of labels applied to this message.
		public let labelIds: [String]
		/// A short part of the message text.
		public let snippet: String?
		/// The ID of the last history record that modified this message
		public let historyId: String?
		/// The parsed email structure in the message parts
		public let payload: Payload?
		/// The internal message creation timestamp (epoch ms), which determines ordering in the inbox. For normal SMTP-received email, this represents the time the message was originally accepted by Google
		public let internalDate: String?
		/// The entire email message in an RFC 2822 format
		public var raw: Data?
		/// Sender of the mail, extracted from `payload.headers`
		public var from: Address? {
			if let addr = headerValue(forName: "FROM") {
				return Address(rawValue: addr)
			}
			return nil
		}
		/// Receriver of the mail, extracted from `payload.headers`
		public var to: [Address]? { [Address](headerValue(forName: "TO")) }
		/// CCs of the mail, extracted from `payload.headers`
		public var cc: [Address]? { [Address](headerValue(forName: "CC")) }
		/// Subject of the mail, extracted from `payload.headers`
		public var subject: String? { headerValue(forName: "SUBJECT") }
		
		func headerValue (forName name: String) -> String? {
			guard let headers = payload?.headers else {
				return nil
			}
			return headers.first { $0.name.uppercased() == name }?.value
		}
	}
	enum AttachmentStyle: String {
		/// Will display attachment as part of the email body
		case inline = "inline"
		/// Will send it as an actual attachment
		case attachment = "attachment"
	}
}
public extension Array where Element == GMail.Address {
	/// Parse a comma separated email addresses string
	init? (_ str: String?) {
		if let comps = str?.components(separatedBy: ", ") {
			self = comps.compactMap { Element(rawValue: $0) }
			return
		}
		return nil
	}
	
}
