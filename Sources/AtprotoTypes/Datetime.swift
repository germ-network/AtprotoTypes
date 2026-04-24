//
//  Datetime.swift
//  AtprotoTypes
//
//  Created by Anna on 4/24/26.
//

import Foundation

// An RFC 3339 formatted timestamp.
// This is technically ISO 8601 which is similar but not exactly the same.

extension Atproto {
	public struct Datetime: Equatable, Hashable, Sendable {
		public var date: Date

		public init(date: Date) {
			self.date = date
		}
		
		public init?(date: Date?) {
			if let date {
				self.init(date: date)
			} else {
				return nil
			}
		}
	}
}

extension Atproto.Datetime {
	static public func mock() -> Self {
		.init(date: .now)
	}
}

//code it as the bare string so we can type fields
extension Atproto.Datetime: Codable {
	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		let dateString = try container.decode(String.self)
		let date = try ISO8601DateFormatter().date(from: dateString).tryUnwrap
		self = .init(date: date)
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(ISO8601DateFormatter().string(from: date))
	}
}
