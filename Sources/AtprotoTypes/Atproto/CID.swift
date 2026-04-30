//
//  CID.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 2/18/26.
//

import Base32
import Foundation

//https://dasl.ing/cid.html
//https://atproto.com/specs/data-model#link-and-cid-formats

extension Atproto {
	public struct CID: Sendable, Hashable {
		//todo: further parse components of the CID data such as the hash
		let bytes: Data

		package init(bytes: Data) {
			self.bytes = bytes
		}

		public init(string: String) throws {
			guard let prefix = string.first, prefix == "b" else {
				throw Atproto.Errors.invalidPrefix
			}
			let body = String(string.dropFirst())

			//cautious about the force unwraps in the Base32 module
			guard !body.isEmpty else {
				throw Atproto.Errors.invalidBase32Data
			}

			guard let decoded = body.base32DecodedData else {
				throw Atproto.Errors.invalidBase32Data
			}

			bytes = decoded
		}

		public var string: String {
			// CID is DASL-compatible (https://atproto.com/specs/data-model)
			// and DASL CID uses lowercase base-32 (https://dasl.ing/cid.html)
			"b" + bytes.base32EncodedStringNoPadding.lowercased()
		}
	}
}

extension Atproto.CID: Codable {
	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		self = try .init(string: container.decode(String.self))
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(self.string)
	}
}
