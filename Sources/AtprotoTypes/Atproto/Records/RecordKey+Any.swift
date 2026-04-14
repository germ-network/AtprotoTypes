//
//  RecordKey+Any.swift
//  AtprotoTypes
//
//  Created by Anna on 4/3/26.
//

import Foundation
import Logging

///https://atproto.com/specs/record-key
extension Atproto {
	public struct AnyRecordKey: Sendable, Equatable {
		public let rawValue: String

		private static let allowedCharacters = CharacterSet.alphanumerics.union(
			CharacterSet(charactersIn: ".-_:~"))

		public init(unchecked: String) throws {
			guard
				Self.allowedCharacters.isSuperset(
					of: CharacterSet(charactersIn: unchecked))
			else {
				throw Lexicon.RecordKeyError.disallowedCharacter
			}
			guard (1...512).contains(unchecked.count) else {
				throw Lexicon.RecordKeyError.wrongLength
			}
			guard ![".", ".."].contains(unchecked) else {
				throw Lexicon.RecordKeyError.disallowedKeyValue
			}
			self.rawValue = unchecked
		}

		package init(knownValue: String) {
			self.rawValue = knownValue
		}
	}
}

extension Atproto.AnyRecordKey: Atproto.RecordKey {
	public init?(rawValue: String) {
		do {
			try self.init(unchecked: rawValue)
		} catch {
			Logger(label: "Atproto.AnyRecordKey")
				.log(level: .error, "Error parsing RecordKey: \(error)")
			return nil
		}
	}
}

//code it as the bare string so we can type fields
extension Atproto.AnyRecordKey: Codable {
	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		self = try .init(unchecked: container.decode(String.self))
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(rawValue)
	}
}
