//
//  GMail.Message.Encode.swift
//  
//
//  Created by Adhiraj Singh on 5/21/20.
//	Encoding code inspired from Swift-SMTP https://github.com/IBM-Swift/Swift-SMTP/blob/master/Sources/SwiftSMTP/DataSender.swift
//	Code has been re-worked to work correctly with GMail specifically, though it should work with other mail providers as well

import Foundation

/// Line break for encoding emails
let CRLF = "\r\n"

extension GMail.Message {
	/// Encode the message to RFC-2822
	func encoded () -> Data {
		var data = Data() // container for all the data we write
		// first write the headers
		write(headers: payload!.headers, to: &data)
		// if the message has attachments, write a mixed message
		if payload!.parts!.count > 0 {
			write(mixedTo: &data)
        } else { // otherwise just write the content
			write(contentTo: &data)
        }
		return data
	}
}

private extension GMail.Message {
	/// Write headers to `data`
	func write(headers: [Header], to data: inout Data) {
		if headers.count > 0 {
			write(headers.toString(), to: &data)
			write(CRLF, to: &data)
		}
    }
	/// Write the main body content to `data`
    func write(contentTo data: inout Data) {
		let boundary = String.makeBoundary()
		let alternativeHeader = String.makeAlternativeHeader(boundary: boundary)
		write(alternativeHeader, to: &data)
		
		write(boundary.startLine, to: &data)
		
		write(CRLF, to: &data)
		write("CONTENT-DISPOSITION: inline\(CRLF)", to: &data)
		write("CONTENT-TYPE: text/html; charset=\"UTF-8\"\(CRLF+CRLF)", to: &data)
		write(payload!.body!.data!, to: &data)
		write(CRLF+CRLF, to: &data)
		
		write(boundary.endLine, to: &data)
	}
	/// Write a mixed (inline body + attachments) type message to `data`
    func write(mixedTo data: inout Data) {
        let boundary = String.makeBoundary()
        let mixedHeader = String.makeMixedHeader(boundary: boundary)

        write(mixedHeader, to: &data)
        write(boundary.startLine, to: &data)
		
		write(CRLF, to: &data)
		write(contentTo: &data)
		
		write(attachments: payload!.parts!, boundary: boundary, to: &data)
		
		write(boundary.endLine, to: &data)
    }
	/// Write some attachments to `data`
	func write(attachments: [Payload], boundary: String, to data: inout Data) {
		write(CRLF, to: &data)
		for attachment in attachments {
			write(boundary.startLine, to: &data)
			write(CRLF, to: &data)
			write(attachment: attachment, to: &data)
			write(CRLF, to: &data)
		}
	}
	/// Write an attachment to `data`
	func write(attachment: Payload, to data: inout Data) {
        var relatedBoundary = ""

        if let _ = attachment.parts {
            relatedBoundary = String.makeBoundary()
            let relatedHeader = String.makeRelatedHeader(boundary: relatedBoundary)
			write(relatedHeader, to: &data)
            write(relatedBoundary.startLine, to: &data)
        }

		write(headers: attachment.headers, to: &data)
		write(CRLF, to: &data)
		write(data: attachment.body!.data!, to: &data)

        if let parts = attachment.parts {
			write(attachments: parts, boundary: relatedBoundary, to: &data)
        }
    }
	/// Base64 encode & write to `data`
	func write(data obj: Data, to data: inout Data) {
		write(obj.base64EncodedData(), to: &data)
    }
	/// Write some text as UTF-8 encoded
	func write(_ text: String, to data: inout Data) {
		write(Data(text.utf8), to: &data)
    }
	func write(_ obj: Data, to data: inout Data) {
		data.append(obj)
    }
}
private extension Array where Element == GMail.Message.Header {
	func toString () -> String {
		map { "\($0.name): \($0.value)"}.joined(separator: CRLF)
	}
}

extension String {
    // The SMTP protocol requires unique boundaries between sections of an email.
    static func makeBoundary() -> String {
		UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    // Header for a mixed type email.
    static func makeMixedHeader(boundary: String) -> String {
		"CONTENT-TYPE: multipart/mixed; boundary=\"\(boundary)\"\(CRLF+CRLF)"
    }
    // Header for an alternative email.
    static func makeAlternativeHeader(boundary: String) -> String {
		"CONTENT-TYPE: multipart/alternative; boundary=\"\(boundary)\"\(CRLF+CRLF)"
    }
    // Header for an attachment that is related to another attachment. (Such as an image attachment that can be
    // referenced by a related HTML attachment)
    static func makeRelatedHeader(boundary: String) -> String {
		"CONTENT-TYPE: multipart/related; boundary=\"\(boundary)\"\(CRLF+CRLF)"
    }
    // Added to a boundary to indicate the beginning of the corresponding section.
    var startLine: String {
		"--\(self)"
    }
    // Added to a boundary to indicate the end of the corresponding section.
    var endLine: String {
		"--\(self)--"
    }
}
