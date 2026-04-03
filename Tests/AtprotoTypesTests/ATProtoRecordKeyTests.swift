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
		#expect(throws: Atproto.RecordKeyError.wrongLength) {
			let _ = try Atproto.RecordKey(rawValue: "")
		}

		#expect(throws: Atproto.RecordKeyError.wrongLength) {
			let _ = try Atproto.RecordKey(rawValue: String(repeating: "a", count: 513))
		}
	}

	@Test func testEncodingDecoding() throws {
		let rkey = Atproto.RecordKey.mock()
		let encoded = try JSONEncoder().encode(rkey)
		let decoded = try JSONDecoder().decode(Atproto.RecordKey.self, from: encoded)
		#expect(rkey == decoded)
	}

}
