//
//  RecordKey.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/3/26.
//

import Foundation

extension Lexicon {
	public protocol RecordKey: Codable, Sendable {
		init(string: String) throws
		var stringRepresentation: String { get }
	}

	//may be dynamic as in a TID or a single fixed value as in a Literal
	public protocol DefaultableRecordKey: RecordKey {
		static func defaultValue() -> Self
	}

	public protocol LiteralRecordKey: DefaultableRecordKey {
		init()
		static var fixedValue: String { get }
	}

	public struct LiteralSelfRecordKey: LiteralRecordKey {
		public static var fixedValue: String { "self" }
		public var stringRepresentation: String {
			Self.fixedValue
		}
		public init() {}
	}
}

extension Lexicon.LiteralRecordKey {
	static public func defaultValue() -> Self {
		.init()
	}

	public init(string: String) throws {
		guard string == Self.fixedValue else {
			throw Lexicon.RecordKeyError.incorrectLiteral
		}
		self.init()
	}
}

extension Atproto.TID: Lexicon.RecordKey {}

extension Atproto.NSID: Lexicon.RecordKey {
	public var stringRepresentation: String {
		self
	}

	public init(string: String) throws {
		self = string
	}
}

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
