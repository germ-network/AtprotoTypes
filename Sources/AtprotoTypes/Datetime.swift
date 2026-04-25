//
//  Datetime.swift
//  AtprotoTypes
//
//  Created by Anna on 4/24/26.
//

import Foundation

// Intersecting requirements of RFC 3339, ISO 8601, and WHATWG HTML
// https://atproto.com/specs/lexicon#datetime

extension Atproto {
	public struct Datetime: RawRepresentable, Codable, Equatable, Hashable, Sendable {
		public var rawValue: String

		public init(date: Date) {
			self.rawValue = ISO8601DateFormatter().string(from: date)
		}

		public init?(rawValue: String) {
			let baseFormat = Date.ISO8601FormatStyle()
				.year()
				.month()
				.day()
				.dateSeparator(.dash)
				.timeSeparator(.colon)

			if let date =
				try? baseFormat
				.time(includingFractionalSeconds: true)
				.parse(rawValue)
			{
				// ISO 8601 with fractional seconds
				self.init(date: date)
			} else if let date =
				try? baseFormat
				.time(includingFractionalSeconds: false)
				.parse(rawValue)
			{
				// ISO 8601 without fractional seconds
				self.init(date: date)
			} else {
				// No way to parse this in ISO 8601
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
