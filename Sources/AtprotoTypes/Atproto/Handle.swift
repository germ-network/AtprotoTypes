//
//  Handle.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/11/26.
//

import Foundation

///https://atproto.com/specs/handle
///Define this as a struct and not a typealias so we can add format checking later
extension Atproto {
	public struct Handle: RawRepresentable, Sendable {
		public let rawValue: String

		public init?(rawValue: String) {
			self.rawValue = rawValue
		}

		public init(atURI: ATURI) {
			self.rawValue = String(atURI.rawValue.trimmingPrefix("at://"))
		}

		var string: String {
			rawValue
		}
	}
}

extension Atproto.Handle: Codable {}
