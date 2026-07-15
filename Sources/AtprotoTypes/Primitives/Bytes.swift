//
//  Bytes.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 3/17/26.
//

import Foundation

extension Atproto.Primitive {
	public struct Bytes: Codable, Hashable, Sendable {
		public let bytes: Data

		public init(bytes: Data) {
			self.bytes = bytes
		}

		public enum CodingKeys: String, CodingKey {
			case bytes = "$bytes"
		}

		//The atproto data model encodes $bytes as base64 WITHOUT padding, which
		//Foundation's base64 decoder rejects — so synthesized Codable (JSONDecoder's
		//.base64 Data strategy) fails on any spec-compliant PDS whose byte length
		//isn't a multiple of 3. Accept both unpadded (spec) and padded (records we
		//previously wrote) forms on decode; emit the spec's unpadded form on encode.
		public init(from decoder: any Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			let encoded = try container.decode(String.self, forKey: .bytes)
			let remainder = encoded.count % 4
			let padded =
				remainder == 0
				? encoded
				: encoded + String(repeating: "=", count: 4 - remainder)
			guard let bytes = Data(base64Encoded: padded) else {
				throw DecodingError.dataCorruptedError(
					forKey: .bytes,
					in: container,
					debugDescription: "Invalid base64 in $bytes"
				)
			}
			self.bytes = bytes
		}

		public func encode(to encoder: any Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)
			var encoded = bytes.base64EncodedString()
			while encoded.hasSuffix("=") { encoded.removeLast() }
			try container.encode(encoded, forKey: .bytes)
		}
	}
}
