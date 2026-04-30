//
//  FixedValueDecoding.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/14/26.
//

import AtprotoTypes
import Foundation
import Testing

struct FixedValueDecodingTests {
	struct Mock: Codable, Equatable {
		let rkey: Atproto.LiteralSelfRecordKey
	}

	@Test("Fixed Value Decoding")
	func testDecode() throws {
		let mock = Mock(rkey: .init())

		let encoded = try JSONEncoder().encode(mock)
		let decoded = try JSONDecoder().decode(Mock.self, from: encoded)

		#expect(mock == decoded)

		let synthetic = "{\"rkey\": \"literal:none\"}"
		#expect(throws: Atproto.Errors.fixedStringMismatch) {
			let _ = try JSONDecoder().decode(
				Mock.self,
				from: synthetic.utf8Data
			)
		}
	}
}
