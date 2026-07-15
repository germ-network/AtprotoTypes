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

		//Decoding stays synthesized: whether unpadded base64 is accepted is the
		//DECODER's choice — use JSONDecoder.atproto (or .dataDecodingStrategy =
		//.atprotoBase64) when reading data-model JSON; a default JSONDecoder keeps
		//Foundation's strict padded-only behavior.
		//
		//Encoding emits the data model's canonical form: base64 without padding.
		public func encode(to encoder: any Encoder) throws {
			var container = encoder.container(keyedBy: CodingKeys.self)
			var encoded = bytes.base64EncodedString()
			while encoded.hasSuffix("=") { encoded.removeLast() }
			try container.encode(encoded, forKey: .bytes)
		}
	}
}
