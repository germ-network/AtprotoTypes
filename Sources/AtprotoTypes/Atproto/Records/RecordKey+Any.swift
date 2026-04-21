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

		public init(string: String) throws {
			guard
				Self.allowedCharacters.isSuperset(
					of: CharacterSet(charactersIn: string))
			else {
				throw Lexicon.RecordKeyError.disallowedCharacter
			}
			guard (1...512).contains(string.count) else {
				throw Lexicon.RecordKeyError.wrongLength
			}
			guard ![".", ".."].contains(string) else {
				throw Lexicon.RecordKeyError.disallowedKeyValue
			}
			self.rawValue = string
		}

		package init(knownValue: String) {
			self.rawValue = knownValue
		}
	}
}

extension Atproto.AnyRecordKey: Atproto.RecordKey {}
