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
	public enum AtIdentifier: Atproto.StringRepresentable, Codable {
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
			//prefix contains a colon which is not permitted in a handle
			if string.hasPrefix(Atproto.DID.Constants.prefix) {
				self = try .did(.init(string: string))
			} else {
				self = .handle(try .init(string: string))
			}
		}

		package init(knownDID: Atproto.DID) {
			self = .did(knownDID)
		}
	}
}
