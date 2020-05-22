//
//  GMail.swift
//  
//
//  Created by Adhiraj Singh on 5/22/20.
//

import Foundation

public extension GMail {
	/// Address of the sender or receiver of a mail
	enum Address: RawRepresentable {
		case email (String)
		case namedEmail (String, String)
		
		/// Parse an address from a string
		public init?(rawValue: String) {
			if let emailStart = rawValue.firstIndex(of: "<") {
				if let emailEnd = rawValue.lastIndex(of: ">"),
					emailStart < emailEnd {
					
					let email = rawValue[rawValue.index(after: emailStart)..<emailEnd]
					
					if rawValue.distance(from: rawValue.startIndex, to: emailStart) > 2 {
						let nameEnd = rawValue.index(emailStart, offsetBy: -2)
						let name = rawValue[rawValue.startIndex...nameEnd]
						self = .namedEmail(String(name), String(email))
					} else {
						self = .email(String(email))
					}
					return
				}
			} else if !rawValue.isEmpty {
				self = .email(rawValue)
				return
			}
			return nil
		}
		/// Formatted raw value.
		/// just the email in case of .email.
		/// Name <EMail> in case of .namedEmail
		public var rawValue: String {
			switch self {
			case .email(let email):
				return email
			case .namedEmail(let name, let email):
				return "\(name) <\(email)>"
			}
		}
		/// The email address
		public var email: String {
			switch self {
			case .email(let email):
				return email
			case .namedEmail(_, let email):
				return email
			}
		}
	}
	
}
