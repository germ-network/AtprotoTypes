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

		init(knownValue: String) {
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

extension LexiconTypes.AnyRecordKey: Mockable {
	//generate test did per the spec https://github.com/did-method-plc/did-method-plc
	static let lowercaseAlpha = (UInt8(ascii: "a")...UInt8(ascii: "z"))
		.map { Character(UnicodeScalar($0)) }

	static let numeric = (UInt8(ascii: "0")...UInt8(ascii: "9"))
		.map { Character(UnicodeScalar($0)) }
	static let base32Set: [Character] = lowercaseAlpha + numeric

	//for web
	static let uppercaseAlpha = (UInt8(ascii: "A")...UInt8(ascii: "Z"))
		.map { Character(UnicodeScalar($0)) }
	static let domainSet =
		lowercaseAlpha + uppercaseAlpha + numeric + [".", "-", "_", ":", "~"]

	public static func mock() -> LexiconTypes.AnyRecordKey {
		.init(
			knownValue: String(
				(3...512).compactMap { _ in domainSet.randomElement() }
			)
		)
	}
}
