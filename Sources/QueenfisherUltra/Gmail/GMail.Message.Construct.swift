//
//  File.swift
//  
//
//  Created by Adhiraj Singh on 5/22/20.
//

import Foundation

public extension GMail.Message {
	
	init? (from: GMail.Address? = nil,
		   replyingTo message: GMail.Message,
		   cc: [GMail.Address] = [],
		   bcc: [GMail.Address] = [],
		   replyAll: Bool = false,
		   text: String = "",
		   attachments: [Payload] = []) {
		
		guard let subject = message.subject,
			  let _ = message.from,
			  let to = message.to?.filter ({ $0.email != from?.email }),
			  let id = message.headerValue(forName: "MESSAGE-ID"),
			  to.count > 0 else {
			return nil
		}
		var totalCC = cc
		if replyAll, let mCC = message.cc {
			totalCC += mCC
		}
		
		var headers: [Header] = [
			.init(name: "IN-REPLY-TO", value: id),
			.init(name: "REFERENCES", value: id)
		]
		if let references = message.headerValue(forName: "REFERENCES") {
			headers[headers.count-1].value = references
		}
		
		self = .init(from: from,
					 to: to,
					 cc: totalCC,
					 bcc: bcc,
					 subject: "Re: " + subject,
					 text: text,
					 threadId: message.threadId,
					 additionalHeaders: headers,
					 attachments: attachments)
	}
	
	init (from: GMail.Address? = nil,
				 to: [GMail.Address],
				 cc: [GMail.Address] = [],
				 bcc: [GMail.Address] = [],
				 subject: String,
				 text: String = "",
				 threadId: String = "",
				 additionalHeaders: [Header] = [],
				 attachments: [Payload] = []) {
		self.threadId = threadId
		self.labelIds = ["SENT"]
		self.snippet = nil
		self.historyId = nil
		self.internalDate = String(Int(Date().timeIntervalSince1970))
		
		var headers = additionalHeaders
		if let idHeader = headers.first(where: { $0.name == "MESSAGE-ID" }) {
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
		headers.append(.init(name: "MIME-VERSION", value: "1.0 (QueenfisherUltra)"))
		
		let body = Data(text.utf8)
		let payload = Payload(partId: "", mimeType: "text/html",
							  filename: "", headers: headers,
							  body: .init(size: body.count, data: body),
							  parts: attachments)
		self.payload = payload
		self.raw = encoded()
	}
}
public extension GMail.Message.Payload {
	
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
