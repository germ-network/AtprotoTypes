//
//  AtprotoJSONDecoder.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 7/15/26.
//

import Foundation

extension JSONDecoder.DataDecodingStrategy {
	//The atproto data model serializes bytes as base64 WITHOUT padding — the form
	//spec-compliant PDSes emit when re-serializing a record from CBOR — which
	//Foundation's default .base64 strategy rejects unless the byte length happens
	//to align to a multiple of 3. Accepts both the unpadded (spec) and padded
	//(records we previously wrote) forms.
	public static var atprotoBase64: JSONDecoder.DataDecodingStrategy {
		.custom { decoder in
			let container = try decoder.singleValueContainer()
			let encoded = try container.decode(String.self)
			let remainder = encoded.count % 4
			let padded =
				remainder == 0
				? encoded
				: encoded + String(repeating: "=", count: 4 - remainder)
			guard let bytes = Data(base64Encoded: padded) else {
				throw DecodingError.dataCorruptedError(
					in: container,
					debugDescription: "Invalid base64 in bytes field"
				)
			}
			return bytes
		}
	}
}

extension JSONDecoder {
	//A decoder configured for atproto data-model JSON. XRPC response parsing
	//reads through this; anything else decoding data-model JSON (records,
	//lexicon bytes) should too.
	public static var atproto: JSONDecoder {
		let decoder = JSONDecoder()
		decoder.dataDecodingStrategy = .atprotoBase64
		return decoder
	}
}
