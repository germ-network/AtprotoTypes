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
	public protocol LiteralRecordKey: RecordKey {
		static var fixedValue: String { get }
	}
	public struct LiteralSelfRecordKey: LiteralRecordKey {
		public static let fixedValue: String = "self"
		public var stringRepresentation: String {
			Self.fixedValue
		}
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
