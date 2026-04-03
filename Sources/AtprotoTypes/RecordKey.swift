//
//  RecordKey.swift
//  AtprotoTypes
//
//  Created by Anna on 4/3/26.
//

import Foundation

///https://atproto.com/specs/record-key

extension Atproto {
	public struct RecordKey: Sendable, Equatable {
		public let rawValue: String

		private static let allowedCharacters = CharacterSet.alphanumerics.union(
			CharacterSet(charactersIn: ".-_:~"))

		public init(rawValue: String) throws {
			guard
				Self.allowedCharacters.isSuperset(
					of: CharacterSet(charactersIn: rawValue))
			else {
				throw Atproto.RecordKeyError.disallowedCharacter
			}
			guard (1...512).contains(rawValue.count) else {
				throw Atproto.RecordKeyError.wrongLength
			}
			guard ![".", ".."].contains(rawValue) else {
				throw Atproto.RecordKeyError.disallowedKeyValue
			}
			self.rawValue = rawValue
		}

		private init(knownValue: String) {
			self.rawValue = knownValue
		}
	}
}

//code it as the bare string so we can type fields
extension Atproto.RecordKey: Codable {
	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		self = try .init(rawValue: container.decode(String.self))
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}
}

extension Atproto.RecordKey: Mockable {
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

	public static func mock() -> Atproto.RecordKey {
		.init(
			knownValue: String(
				(3...512).compactMap { _ in domainSet.randomElement() }
			)
		)
	}
}

extension Atproto {
	public enum RecordKeyError: LocalizedError {
		case wrongLength
		case disallowedCharacter
		case disallowedKeyValue

		public var errorDescription: String? {
			switch self {
			case .wrongLength: "Wrong length"
			case .disallowedCharacter: "Disallowed character"
			case .disallowedKeyValue: "Disallowed key value"
			}
		}
	}
}
