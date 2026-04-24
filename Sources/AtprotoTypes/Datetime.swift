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
	public struct Datetime: RawRepresentable, Equatable, Hashable, Sendable {
		public var rawValue: String

		public init(date: Date) {
			self.rawValue = ISO8601DateFormatter().string(from: date)
		}
		
		public init?(rawValue: String) {
			do {
				let date = try ISO8601DateFormatter().date(from: rawValue).tryUnwrap
				self.init(date: date)
			} catch {
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
