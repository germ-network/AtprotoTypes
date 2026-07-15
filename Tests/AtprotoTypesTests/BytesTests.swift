//
//  BytesTests.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 7/15/26.
//

import AtprotoTypes
import Foundation
import Testing

struct BytesTests {
	//The atproto data model's $bytes is base64 without padding. A spec-compliant
	//PDS (e.g. rsky/blacksky) re-serializes records that way, so lengths that
	//aren't a multiple of 3 bytes arrive needing padding Foundation won't infer.
	//33 bytes encodes to exactly 44 chars (no padding — the case that always
	//worked); 34 bytes needs "==" (the case synthesized Codable rejected).
	@Test("Decodes unpadded, padded, and alignment-free base64", arguments: [32, 33, 34])
	func decodeBothPaddings(count: Int) throws {
		let value = Atproto.Primitive.Bytes(bytes: Data(repeating: 0xA5, count: count))

		let padded = value.bytes.base64EncodedString()
		var unpadded = padded
		while unpadded.hasSuffix("=") { unpadded.removeLast() }

		for encoded in [padded, unpadded] {
			let json = "{\"$bytes\": \"\(encoded)\"}"
			let decoded = try JSONDecoder().decode(
				Atproto.Primitive.Bytes.self,
				from: json.utf8Data
			)
			#expect(decoded == value)
		}
	}

	@Test("Encodes without padding and round-trips")
	func encodeUnpadded() throws {
		//34 bytes -> padded base64 would end in "=="
		let value = Atproto.Primitive.Bytes(bytes: Data(repeating: 0x5A, count: 34))

		let encoded = try JSONEncoder().encode(value)
		let json = try #require(String(data: encoded, encoding: .utf8))
		#expect(!json.contains("="))

		let decoded = try JSONDecoder().decode(
			Atproto.Primitive.Bytes.self,
			from: encoded
		)
		#expect(decoded == value)
	}

	@Test("Rejects invalid base64")
	func rejectsInvalidBase64() throws {
		let json = "{\"$bytes\": \"not*base64!\"}"
		#expect(throws: DecodingError.self) {
			let _ = try JSONDecoder().decode(
				Atproto.Primitive.Bytes.self,
				from: json.utf8Data
			)
		}
	}
}
