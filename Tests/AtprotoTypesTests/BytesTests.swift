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
	//The atproto data model's bytes are base64 without padding. A spec-compliant
	//PDS (bsky's own included) re-serializes records that way, so lengths that
	//aren't a multiple of 3 bytes arrive needing padding Foundation won't infer.
	//33 bytes encodes to exactly 44 chars (no padding — the case that always
	//worked); 34 bytes needs "==" (the case the default strategy rejects).
	@Test("The atproto decoder accepts unpadded and padded base64", arguments: [32, 33, 34])
	func atprotoDecoderAcceptsBothPaddings(count: Int) throws {
		let value = Atproto.Primitive.Bytes(bytes: Data(repeating: 0xA5, count: count))

		let padded = value.bytes.base64EncodedString()
		var unpadded = padded
		while unpadded.hasSuffix("=") { unpadded.removeLast() }

		for encoded in [padded, unpadded] {
			let json = "{\"$bytes\": \"\(encoded)\"}"
			let decoded = try JSONDecoder.atproto.decode(
				Atproto.Primitive.Bytes.self,
				from: json.utf8Data
			)
			#expect(decoded == value)
		}
	}

	//the tolerance is a decoder option, not a property of Bytes: a default
	//JSONDecoder keeps Foundation's strict padded-only behavior
	@Test func defaultDecoderStaysStrict() throws {
		//34 bytes -> unpadded base64 length isn't a multiple of 4
		var unpadded = Data(repeating: 0xA5, count: 34).base64EncodedString()
		while unpadded.hasSuffix("=") { unpadded.removeLast() }
		let json = "{\"$bytes\": \"\(unpadded)\"}"
		#expect(throws: DecodingError.self) {
			let _ = try JSONDecoder().decode(
				Atproto.Primitive.Bytes.self,
				from: json.utf8Data
			)
		}
	}

	@Test("Encodes without padding and round-trips through the atproto decoder")
	func encodeUnpadded() throws {
		//34 bytes -> padded base64 would end in "=="
		let value = Atproto.Primitive.Bytes(bytes: Data(repeating: 0x5A, count: 34))

		let encoded = try JSONEncoder().encode(value)
		let json = try #require(String(data: encoded, encoding: .utf8))
		#expect(!json.contains("="))

		let decoded = try JSONDecoder.atproto.decode(
			Atproto.Primitive.Bytes.self,
			from: encoded
		)
		#expect(decoded == value)
	}

	@Test("Rejects invalid base64")
	func rejectsInvalidBase64() throws {
		let json = "{\"$bytes\": \"not*base64!\"}"
		#expect(throws: DecodingError.self) {
			let _ = try JSONDecoder.atproto.decode(
				Atproto.Primitive.Bytes.self,
				from: json.utf8Data
			)
		}
	}
}
