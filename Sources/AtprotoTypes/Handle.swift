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
