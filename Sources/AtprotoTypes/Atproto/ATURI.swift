//
//  ATURI.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/14/26.
//

import Foundation

extension Atproto {
	///https://atproto.com/specs/at-uri-scheme

	public struct ATURI: RawRepresentable {
		public let rawValue: String

		public init(rawValue: String) {
			self.rawValue = rawValue
		}
	}
}
