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

		/// https://atproto.com/specs/handle#handle-identifier-syntax
		public init(string: String) throws {
			guard string.count <= 253 else {
				throw Errors.tooLong
			}

			let handleRegex =
				/^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$/

			guard string.wholeMatch(of: handleRegex) != nil else {
				throw Errors.badHandle
			}

			self.rawValue = string
		}

		var string: String {
			rawValue
		}

		public enum Errors: Error, LocalizedError {
			case tooLong
			case badHandle

			public var errorDescription: String {
				switch self {
				case .tooLong: "Too long"
				case .badHandle: "Bad handle"
				}
			}
		}
	}
}

extension Atproto.Handle: Codable {}
