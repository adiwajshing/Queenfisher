//
//  GMail.Message.Construct.swift
//  
//
//  Created by Adhiraj Singh on 5/22/20.
//

import Foundation

public extension GMail.Message {
	/**
	Construct a message replying to another message
	- Parameter from: optionally mention the email and/or name of the sender
	- Parameter replyingTo: the message being replied to
	- Parameter fromMe: was the original message sent by you
	- Parameter replyAll: if true, the mail will be forwarded to all the people CC'd on the original mail
	- Parameter cc: addresses to CC on the mail
	- Parameter bcc: addresses to BCC on the mail
	- Parameter text: html text of the mail
	- Parameter attachments: attachments for the message
	- Returns: a `Message` ready to send using `GMail.send()`
	*/
	init? (from: GMail.Address? = nil,
		   replyingTo message: GMail.Message,
		   fromMe: Bool,
		   replyAll: Bool = false,
		   cc: [GMail.Address] = [],
		   bcc: [GMail.Address] = [],
		   text: String = "",
		   attachments: [Payload] = []) {
		// ensure we have all the parameters in the mail
		guard let subject = message.subject,
			  let mFrom = message.from,
			  var to = message.to?.filter ({ $0.email != from?.email }),
			  let id = message.headerValue(forName: "MESSAGE-ID") else {
			return nil
		}
		// if the message wasn't from oneself, add the sender to the to list
		to += (!fromMe ? [ mFrom ] : [])
		// ensure there are people to send the mail to
		guard to.count > 0 else {
			return nil
		}
		// add the CCs, if replyAll is checked, send to all people CC'd as well
		var totalCC = cc
		if replyAll, let mCC = message.cc {
			totalCC += mCC
		}
		
		// Add the mandatory reply headers & format subject
		// See https://developers.google.com/gmail/api/v1/reference/users/messages/send#request-body
		var headers: [Header] = [
			.init(name: "IN-REPLY-TO", value: id),
			.init(name: "REFERENCES", value: id)
		]
		if let references = message.headerValue(forName: "REFERENCES") {
			headers[headers.count-1].value = references
		}
		let trueSubject = subject.hasPrefix("Re: ") ? subject : "Re: " + subject
		// construct the message
		self = .init(from: from,
					 to: to,
					 cc: totalCC,
					 bcc: bcc,
					 subject: trueSubject,
					 text: text,
					 threadId: message.threadId,
					 additionalHeaders: headers,
					 attachments: attachments)
	}
	/**
	Construct a message to send
	- Parameter from: optionally mention the email and/or name of the sender
	- Parameter to: addresses the mail is being sent to
	- Parameter cc: addresses to CC on the mail
	- Parameter bcc: addresses to BCC on the mail
	- Parameter subject: the subject of the email
	- Parameter text: html text of the mail
	- Parameter threadId: optionally mention the thread this message belongs to
	- Parameter additionalHeaders: some extra headers you may want to attach
	- Parameter attachments: attachments for the message
	- Returns: a `Message` ready to send using `GMail.send()`
	*/
	init (from: GMail.Address? = nil,
				 to: [GMail.Address],
				 cc: [GMail.Address] = [],
				 bcc: [GMail.Address] = [],
				 subject: String,
				 text: String,
				 threadId: String = "",
				 additionalHeaders: [Header] = [],
				 attachments: [Payload] = []) {
		self.threadId = threadId
		self.labelIds = ["SENT"]
		self.snippet = nil
		self.historyId = nil
		self.internalDate = String(Int(Date().timeIntervalSince1970)) // set the epoch time
		
		var headers = additionalHeaders
		if let idHeader = headers.first(where: { $0.name == "MESSAGE-ID" }) { // if the message ID is set, use that
			self.id = idHeader.value
		} else {
			self.id = UUID().uuidString
			headers.append(.init(name: "MESSAGE-ID", value: id))
		}
		if let from = from {
			headers.append(.init(name: "FROM", value: from.rawValue))
		}
		if !cc.isEmpty {
			headers.append( .init(name: "CC", value: cc.map { $0.rawValue }.joined(separator: ", ")) )
		}
		if !bcc.isEmpty {
			headers.append( .init(name: "BCC", value: bcc.map { $0.rawValue }.joined(separator: ", ")) )
		}
		headers.append(.init(name: "DATE", value: Date().smtpFormatted))
		headers.append(.init(name: "TO", value: to.map { $0.rawValue }.joined(separator: ", ")))
		headers.append(.init(name: "SUBJECT", value: subject))
		headers.append(.init(name: "MIME-VERSION", value: "1.0 (Queenfisher)"))
				
		// finally generate the payload
		let body = Data(text.utf8)
		payload = Payload(partId: "", mimeType: "text/html",
							  filename: "", headers: headers,
							  body: .init(size: body.count, data: body),
							  parts: attachments)
		self.raw = encoded() // encode as RFC-2822
	}
}
public extension GMail.Message.Payload {
	
	/**
	Create an attachment from a file
	- Parameter url: the url of the file you want to send
	- Parameter filename: override the filename of the file
	- Parameter mime: mimetype of the file, eg. `image/jpeg`, `video/mp4`
	- Parameter style: send as an inline message or as an attachement
	- Parameter additionalHeaders: some other headers you may want to attach
	- Returns: the nicely formatted payload read to attach to a `Message`
	*/
	static func attachment (fileAt url: URL,
							filename: String? = nil,
							mime: String = "application/octet-stream",
							style: GMail.AttachmentStyle = .attachment,
							additionalHeaders: [GMail.Message.Header] = []) throws -> Self {
		let filename = filename ?? url.lastPathComponent
		let data = try Data(contentsOf: url)
		return .attachment(data: data, filename: filename,
						   mime: mime, style: style,
						   additionalHeaders: additionalHeaders)
	}
	/**
	Create an attachment from some binary data
	- Parameter data: bytes of the file you want to send
	- Parameter filename: name of the file
	- Parameter mime: mimetype of the file, eg. `image/jpeg`, `video/mp4`
	- Parameter style: send as an inline message or as an attachement
	- Parameter additionalHeaders: some other headers you may want to attach
	- Returns: the nicely formatted payload read to attach to a `Message`
	*/
	static func attachment (data: Data,
							filename: String,
							mime: String = "application/octet-stream",
							style: GMail.AttachmentStyle = .attachment,
							additionalHeaders: [GMail.Message.Header] = []) -> Self {
		
		var headers = additionalHeaders
		headers.append(.init(name: "CONTENT-TYPE", value: mime))
		var disposition = style.rawValue
		if !filename.isEmpty {
			disposition.append("; filename=\"\(filename)\"")
		}
		headers.append(.init(name: "CONTENT-DISPOSITION", value: disposition))
		headers.append(.init(name: "CONTENT-TRANSFER-ENCODING", value: "BASE64"))
		
		return .init(partId: nil,
			  mimeType: mime,
			  filename: filename,
			  headers: headers,
			  body: .init(size: data.count,
						  attachmentId: UUID().uuidString,
						  data: data),
			  parts: nil)
	}
}

// Extension from Swift-SMTP - https://github.com/IBM-Swift/Swift-SMTP/blob/master/Sources/SwiftSMTP/DataSender.swift
extension DateFormatter {
    static let smtpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss ZZZ"
        return formatter
    }()
}
extension Date {
    var smtpFormatted: String { DateFormatter.smtpDateFormatter.string(from: self) }
}
