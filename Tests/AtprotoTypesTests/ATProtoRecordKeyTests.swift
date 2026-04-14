//
//  AtprotoRecordKeyTests.swift
//  SwiftAtprotoOAuth
//
//  Created by Anna and Mark on 4/3/26.
//

import AtprotoTypes
import AtprotoTypesMocks
import Foundation
import Testing

struct AtprotoRecordKeyTests {
	@Test func testParse() throws {
		#expect(throws: Lexicon.RecordKeyError.wrongLength) {
			let _ = try Atproto.AnyRecordKey(unchecked: "")
		}

		#expect(throws: Lexicon.RecordKeyError.wrongLength) {
			let _ = try Atproto.AnyRecordKey(
				unchecked: String(repeating: "a", count: 513))
		}
	}

	@Test func testEncodingDecoding() throws {
		let rkey = Atproto.AnyRecordKey.mock()
		let encoded = try JSONEncoder().encode(rkey)
		let decoded = try JSONDecoder().decode(
			Atproto.AnyRecordKey.self, from: encoded)
		#expect(rkey == decoded)
	}

	@Test func testLiteralSelf() throws {
		let rkey = Atproto.LiteralSelfRecordKey()
		let encoded = try JSONEncoder().encode(rkey)

		#expect(encoded == "\"\(Atproto.LiteralSelfRecordKey.fixedValue)\"".utf8Data)

		let decoded = try JSONDecoder().decode(
			Atproto.LiteralSelfRecordKey.self,
			from: encoded
		)
		#expect(rkey == decoded)
	}

	struct MockLiteralKey: FixedString {
		static var fixedValue: String { "mock" }
	}

	@Test func testCustomLiteral() throws {
		let rkey = MockLiteralKey()
		let encoded = try JSONEncoder().encode(rkey)

		#expect(encoded == "\"\(MockLiteralKey.fixedValue)\"".utf8Data)

		let decoded = try JSONDecoder().decode(
			MockLiteralKey.self,
			from: encoded
		)
		#expect(rkey == decoded)
	}
}
