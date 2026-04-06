//
//  AtprotoRecordKeyTests.swift
//  SwiftAtprotoOAuth
//
//  Created by Anna and Mark on 4/3/26.
//

import AtprotoTypes
import Foundation
import Testing

struct AtprotoRecordKeyTests {
	@Test func testParse() throws {
		#expect(throws: Lexicon.RecordKeyError.wrongLength) {
			let _ = try Lexicon.AnyRecordKey(rawValue: "")
		}

		#expect(throws: Lexicon.RecordKeyError.wrongLength) {
			let _ = try Lexicon.AnyRecordKey(
				rawValue: String(repeating: "a", count: 513))
		}
	}

	@Test func testEncodingDecoding() throws {
		let rkey = Lexicon.AnyRecordKey.mock()
		let encoded = try JSONEncoder().encode(rkey)
		let decoded = try JSONDecoder().decode(Lexicon.AnyRecordKey.self, from: encoded)
		#expect(rkey == decoded)
	}

}
