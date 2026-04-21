//
//  AtIdentifier.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 2/18/26.
//

import Foundation

///parameters take a did or handle
///https://atproto.com/specs/lexicon#string-formats
///Like RecordKey, want a family of types representing the fomat restrictions
public enum LexiconString {}

extension LexiconString {
	public enum AtIdentifier: Atproto.StringRepresentable, Codable, Sendable {
		case handle(Atproto.Handle)
		case did(Atproto.DID)

		//over the wire, passed as a string
		public var rawValue: String {
			switch self {
			case .handle(let handle): handle.string
			case .did(let did): did.rawValue
			}
		}

		public init(string: String) throws {
			if let did = Atproto.DID(rawValue: string) {
				self = .did(did)
			} else if let handle = Atproto.Handle(rawValue: string) {
				self = .handle(handle)
			} else {
				throw Errors.unrecognizedStringFormat
			}
		}

		package init(knownDID: Atproto.DID) {
			self = .did(knownDID)
		}

		package init(knownHandle: Atproto.Handle) {
			self = .handle(knownHandle)
		}
	}

	enum Errors: LocalizedError {
		case unrecognizedStringFormat

		var errorDescription: String? {
			switch self {
			case .unrecognizedStringFormat:
				"Unrecognized string format"
			}
		}
	}
}
