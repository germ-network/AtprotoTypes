//
//  RecordKey.swift
//  AtprotoTypes
//
//  Created by Anna on 4/3/26.
//

import Foundation

///https://atproto.com/specs/record-key
public struct RecordKey: Sendable {
	public let rawValue: String

	private static let allowedCharacters = CharacterSet.alphanumerics.union(
		CharacterSet(charactersIn: ".-_:~"))

	init(rawValue: String) throws {
		guard
			RecordKey.allowedCharacters.isSuperset(
				of: CharacterSet(charactersIn: rawValue))
		else {
			throw RecordKeyError.disallowedCharacter
		}
		guard (1...512).contains(rawValue.count) else {
			throw RecordKeyError.wrongLength
		}
		guard ![".", ".."].contains(rawValue) else {
			throw RecordKeyError.disallowedKeyValue
		}
		self.rawValue = rawValue
	}
}

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
