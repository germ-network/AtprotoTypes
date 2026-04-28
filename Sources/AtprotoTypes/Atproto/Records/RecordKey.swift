//
//  RecordKey.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/3/26.
//

import Foundation

extension Atproto {
	public protocol RecordKey: StringRepresentable, Codable, Sendable {
	}

	//may be dynamic as in a TID or a single fixed value as in a Literal
	public protocol DefaultableRecordKey: RecordKey {
		static func defaultValue() -> Self
	}

	public struct LiteralSelfRecordKey: DefaultableRecordKey, FixedString {
		public static var fixedValue: String { "self" }
		public init() {}

		public var rawValue: String { Self.fixedValue }

		public init(from decoder: any Decoder) throws {
			let container = try decoder.singleValueContainer()
			let string = try container.decode(String.self)
			guard string == Self.fixedValue else {
				throw Atproto.Errors.fixedStringMismatch
			}
		}

		public func encode(to encoder: any Encoder) throws {
			var container = encoder.singleValueContainer()
			try container.encode(Self.fixedValue)
		}
	}
}

//default implementations to comform to RecordKey /
extension FixedString {
	static public func defaultValue() -> Self {
		.init()
	}

	public init(string: String) throws {
		guard string == Self.fixedValue else {
			throw Lexicon.RecordKeyError.incorrectLiteral
		}
		self.init()
	}

	public var stringRepresentation: String {
		Self.fixedValue
	}
}

extension Atproto.TID: Atproto.RecordKey {}

extension Lexicon {
	public enum RecordKeyError: LocalizedError {
		case wrongLength
		case disallowedCharacter
		case disallowedKeyValue
		case incorrectLiteral

		public var errorDescription: String? {
			switch self {
			case .wrongLength: "Wrong length"
			case .disallowedCharacter: "Disallowed character"
			case .disallowedKeyValue: "Disallowed key value"
			case .incorrectLiteral: "Incorrect literal"
			}
		}
	}
}
