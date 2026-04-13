//
//  Tid.swift
//  AtprotoTypes
//
//  Created by Anna and Mark on 4/3/26.
//

import Base32
import Foundation

extension Atproto {
	public struct TID: Sendable, Equatable, Hashable {
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
				throw Atproto.TIDError.wrongPrefix
			}

			guard string.count == Self.expectedLength else {
				throw Atproto.TIDError.wrongLength
			}

			guard
				Self.allowedCharacters.isSuperset(
					of: CharacterSet(charactersIn: string))
			else {
				throw Atproto.TIDError.disallowedCharacter
			}

			self.stringEncoded = string
		}

		private init(knownValue: String) {
			self.stringEncoded = knownValue
		}

		public var stringRepresentation: String { stringEncoded }
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

extension Atproto.TID: Codable {
	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		self = try .init(string: container.decode(String.self))
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(self.stringEncoded)
	}
}
