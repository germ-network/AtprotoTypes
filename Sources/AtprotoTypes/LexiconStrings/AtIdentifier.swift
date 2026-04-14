//
//  AtIdentifier.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 2/18/26.
//

import Foundation

///parameters take a did or handle
///https://atproto.com/specs/lexicon#string-formats

public enum LexiconString {}

extension LexiconString {
	public enum AtIdentifier: RawRepresentable, Codable, Sendable {
		case handle(Atproto.Handle)
		case did(Atproto.DID)

		//over the wire, passed as a string
		public var rawValue: String {
			switch self {
			case .handle(let handle): handle.string
			case .did(let did): did.rawValue
			}
		}

		public init?(rawValue: String) {
			if let did = Atproto.DID(rawValue: rawValue) {
				self = .did(did)
			} else if let handle = Atproto.Handle(rawValue: rawValue) {
				self = .handle(handle)
			} else {
				return nil
			}
		}
	}
}
