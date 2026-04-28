//
//  Tid.swift
//  AtprotoTypes
//
//  Created by Anna and Mark on 4/3/26.
//

import Base32
import Foundation

extension Atproto {
	public struct TID: StringRepresentable, Sendable, Equatable, Hashable {
		// TODO: parse it as an int64
		private let stringEncoded: String

		private static let allowedCharacters = CharacterSet(
			charactersIn: "234567abcdefghijklmnopqrstuvwxyz")
		public static let allowedPrefixCharacters = "234567abcdefghij"
		private static let expectedLength = 13

		public init(string: String) throws {
			guard let prefix = string.first,
				Self.allowedPrefixCharacters.contains(prefix)
			else {
				throw Errors.wrongPrefix
			}

			guard string.count == Self.expectedLength else {
				throw Errors.wrongLength
			}

			guard
				Self.allowedCharacters.isSuperset(
					of: CharacterSet(charactersIn: string))
			else {
				throw Errors.disallowedCharacter
			}

			self.stringEncoded = string
		}

		public var rawValue: String { stringEncoded }

		package init(knownValue: String) {
			self.stringEncoded = knownValue
		}
	}
}

extension Atproto.TID {
	public enum Errors: LocalizedError {
		case wrongLength
		case wrongPrefix
		case disallowedCharacter

		public var errorDescription: String? {
			switch self {
			case .wrongLength: "Wrong length"
			case .wrongPrefix: "Wrong prefix"
			case .disallowedCharacter: "Disallowed character"
			}
		}
	}
}
