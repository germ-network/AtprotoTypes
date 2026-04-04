//
//  AtIdentifier.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 2/18/26.
//

import Foundation

///parameters take a did or handle
///https://atproto.com/specs/lexicon#string-formats
public enum AtIdentifier: Sendable {
	public typealias Handle = String

	case handle(Handle)
	case did(Atproto.DID)

	//over the wire, passed as a string
	public var wireFormat: String {
		switch self {
		case .handle(let handle): handle
		case .did(let did): did.stringRepresentation
		}
	}
}

extension AtIdentifier: Codable {
	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(self.wireFormat)
	}

	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		let string = try container.decode(String.self)

		if let did = try? Atproto.DID(string: string) {
			self = .did(did)
		} else {
			self = .handle(string)
		}
	}
}
