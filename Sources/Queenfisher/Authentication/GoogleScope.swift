//
//  GoogleScope.swift
//  
//
//  Created by Adhiraj Singh on 5/22/20.
//

import Foundation

public struct GoogleScope: Codable, RawRepresentable, Equatable, CustomStringConvertible {
	
	public static let sheets: Self = .scope ("https://www.googleapis.com/auth/spreadsheets")!
	public static let storageRead: Self = .scope ("https://www.googleapis.com/auth/devstorage.read_only")!
	
	public static let mailCompose: Self = .scope ("https://www.googleapis.com/auth/gmail.compose")!
	public static let mailRead: Self = .scope ("https://www.googleapis.com/auth/gmail.readonly")!
	public static let mailModify: Self = .scope ("https://www.googleapis.com/auth/gmail.modify")!
	public static let mailFullAccess: Self = .scope("https://mail.google.com/")!
	public static let mailAll: Self = .mailFullAccess + .mailRead + .mailCompose + .mailModify
	
	public static let calender: Self = .scope ("https://www.googleapis.com/auth/calendar")!
	
	public var values: Set<URL>
	public var scopes: [GoogleScope] { values.map { .scope($0) } }
	
	public var rawValue: String {
		values.map { $0.absoluteString }.joined(separator: " ")
	}
	public var description: String {
		"GoogleScope(" + values.map { $0.lastPathComponent }.joined(separator: ", ") + ")"
	}
	
	public init (values: Set<URL>) {
		self.values = values
	}
	public init?(rawValue: String) {
		let comps = rawValue.components(separatedBy: " ")
		values = Set(comps.compactMap { URL(string: $0) })
	}
	public init (from decoder: Decoder) throws {
		self.init(rawValue: try .init(from: decoder))!
	}
	public func encode(to encoder: Encoder) throws {
		try rawValue.encode(to: encoder)
	}
	
	public func contains (_ scope: Self) -> Bool {
		scope.values.isSubset(of: values)
	}
	public func containsAny (_ scope: Self) -> Bool {
		scope.values.intersection(scope.values).count > 0
	}
	
	public static func scope (_ urlString: String) -> Self? {
		if let url = URL(string: urlString) {
			return .init(values: [url])
		}
		return nil
	}
	public static func scope (_ url: URL) -> Self {
		.init(values: [url])
	}
	public static func + (lhs: Self, rhs: Self) -> Self {
		.init(values: lhs.values.union(rhs.values))
	}
	public static func += (lhs: inout Self, rhs: Self) {
		lhs.values.formUnion(rhs.values)
	}
	public static func == (lhs: Self, rhs: Self) -> Bool {
		lhs.values == rhs.values
	}
}
