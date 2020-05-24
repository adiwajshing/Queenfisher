//
//  ActivePhoneCall.swift
//  
//
//  Created by Adhiraj Singh on 5/24/20.
//

import Foundation

/**
Structure that maintains the metadata of an active phone call.
We pretend a DB of these records exists & must be synced with a google sheet. We test `IndexedSheet` using this DB.
*/
public struct ActivePhoneCall: Comparable {
	var startOfCall: Date
	/// 10 digit phone number of caller
	var fromNumber: String
	/// 10 digit phone number of receiver
	var toNumber: String
	
	/// Create a random active phone call record
	static func random () -> ActivePhoneCall {
		let from = (1000000000...9999999999).randomElement()! // 10 digit phone number
		let to   = (1000000000...9999999999).randomElement()! // 10 digit phone number
		let start = Date(timeIntervalSinceReferenceDate: Double.random(in: -10000...1000000))
		return .init(startOfCall: start, fromNumber: String(from), toNumber: String(to))
	}
	public static func < (lhs: ActivePhoneCall, rhs: ActivePhoneCall) -> Bool {
		if lhs.startOfCall < rhs.startOfCall {
			return true
		} else if lhs.startOfCall > rhs.startOfCall {
			return false
		} else {
			return lhs.fromNumber < rhs.fromNumber
		}
	}
}
// Methods and properties to assist in managing the Sheets DB
public extension ActivePhoneCall {
	/// sheet in which the DB will exist
	static let sheetTitle = "ActiveNumbersTest"
	/// Method to convert a row in the sheets DB to an index
	/// We sort the DB by `startOfCall`, `from`
	static let indexer: (([String]) -> String) = {
		// pad the date & add the phone number. This ensures comparisons between strings of equal lengths
		String(format: "%08X", UInt32(dateFormatter.date(from: $0[0])!.timeIntervalSince1970))
		+ $0[1]
	}
	/// The header for the sheets DB
	static let header: [String] = ["Conversation Start", "From", "To"]
	/// What the string key would look like
	func dbKey () -> String {
		String(format: "%08X", UInt32(startOfCall.timeIntervalSince1970)) + fromNumber
	}
	/// Convert to a row to put into the sheets DB
	func row () -> [String] {
		[
			dateFormatter.string(from: startOfCall),
			fromNumber,
			toNumber
		]
	}
}

var dateFormatter: DateFormatter = {
	let formatter = DateFormatter ()
	formatter.dateFormat = "yy/MM/dd hh:mm:ss a"
	return formatter
} ()
