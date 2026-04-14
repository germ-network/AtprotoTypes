//
//  Bytes.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 3/17/26.
//

import Foundation

extension Atproto.Primitive {
	public struct LexiconBytes: Codable, Hashable, Sendable {
		public let bytes: Data

		public init(bytes: Data) {
			self.bytes = bytes
		}

		public enum CodingKeys: String, CodingKey {
			case bytes = "$bytes"
		}
	}
}
