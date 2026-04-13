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
	public struct Handle: Sendable {
		private let rawValue: String

		init(string: String) throws {
			self.rawValue = string
		}

		var string: String {
			rawValue
		}
	}
}

extension Atproto.Handle: Codable {
	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		self = try .init(string: container.decode(String.self))
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(string)
	}
}
