//
//  RecordKey+Any.swift
//  AtprotoTypes
//
//  Created by Anna on 4/3/26.
//

import Foundation

///https://atproto.com/specs/record-key
extension LexiconTypes {
	public struct AnyRecordKey: Sendable, Equatable {
		public let rawValue: String

		private static let allowedCharacters = CharacterSet.alphanumerics.union(
			CharacterSet(charactersIn: ".-_:~"))

		public init(rawValue: String) throws {
			guard
				Self.allowedCharacters.isSuperset(
					of: CharacterSet(charactersIn: rawValue))
			else {
				throw Lexicon.RecordKeyError.disallowedCharacter
			}
			guard (1...512).contains(rawValue.count) else {
				throw Lexicon.RecordKeyError.wrongLength
			}
			guard ![".", ".."].contains(rawValue) else {
				throw Lexicon.RecordKeyError.disallowedKeyValue
			}
			self.rawValue = rawValue
		}

		package init(knownValue: String) {
			self.rawValue = knownValue
		}
	}
}

extension LexiconTypes.AnyRecordKey: LexiconTypes.RecordKey {
	public var stringRepresentation: String { rawValue }
	public init(string: String) throws {
		try self.init(rawValue: string)
	}
}

//code it as the bare string so we can type fields
extension LexiconTypes.AnyRecordKey: Codable {
	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		self = try .init(rawValue: container.decode(String.self))
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}
}
