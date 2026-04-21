//
//  ATURI.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/14/26.
//

import Foundation

extension Atproto {
	///https://atproto.com/specs/at-uri-scheme

	public struct ATURI: StringRepresentable, Sendable, Codable {
		public let rawValue: String

		public init(string: String) {
			self.rawValue = string
		}
	}
}
