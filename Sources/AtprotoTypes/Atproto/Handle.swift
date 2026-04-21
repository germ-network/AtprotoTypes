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
	public struct Handle: StringRepresentable, Sendable {
		public let rawValue: String

		public init(string: String) {
			self.rawValue = string
		}

		var string: String {
			rawValue
		}
	}
}

extension Atproto.Handle: Codable {}
