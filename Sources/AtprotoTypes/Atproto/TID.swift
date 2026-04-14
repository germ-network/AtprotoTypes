//
//  Tid.swift
//  AtprotoTypes
//
//  Created by Anna and Mark on 4/3/26.
//

import Base32
import Foundation

extension Atproto {
	public struct TID: RawRepresentable, Sendable, Equatable, Hashable {
		// TODO: parse it as an int64
		private let stringEncoded: String

		private static let allowedCharacters = CharacterSet(
			charactersIn: "234567abcdefghijklmnopqrstuvwxyz")
		public static let allowedPrefixCharacters = "234567abcdefghij"
		private static let expectedLength = 13

		public init?(rawValue: String) {
			guard let prefix = rawValue.first,
				Self.allowedPrefixCharacters.contains(prefix)
			else {
				return nil
			}

			guard rawValue.count == Self.expectedLength else {
				return nil
			}

			guard
				Self.allowedCharacters.isSuperset(
					of: CharacterSet(charactersIn: rawValue))
			else {
				return nil
			}

			self.stringEncoded = rawValue
		}

		public var rawValue: String { stringEncoded }

		package init(knownValue: String) {
			self.stringEncoded = knownValue
		}
	}
}

extension Atproto {
	public enum TIDError: LocalizedError {
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
