//
//  RecordKeys.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/3/26.
//

import Foundation

extension Lexicon {
	public protocol RecordKey: Codable, Sendable {
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
}

extension Lexicon.AnyRecordKey: Lexicon.RecordKey {
	public var stringRepresentation: String { rawValue }
}
extension Atproto.TID: Lexicon.RecordKey {}
extension Atproto.NSID: Lexicon.RecordKey {
	public var stringRepresentation: String {
		self
	}
}
