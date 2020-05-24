//
//  GMail.swift
//  
//
//  Created by Adhiraj Singh on 5/22/20.
//

import Foundation

public extension GMail {
	/// Address of the sender or receiver of a mail
	struct Address: RawRepresentable {
		public var name: String?
		public var email: String
		
		init (name: String?, email: String) {
			self.name = name
			self.email = email
		}
		
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
			name != nil ? "\(name!) <\(email)>" : email
		}
		/// Address with just an email
		static func email (_ str: String) -> Address {
			.init (name: nil, email: str)
		}
		/// Address with a name & email
		static func namedEmail (_ name: String, _ str: String) -> Address {
			.init (name: name, email: str)
		}
	}
	
}
