//
//  StringEncodingTests.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/24/26.
//

import AtprotoTypes
import Foundation
import Testing

struct StringEncodingTests {
	@Test func testLiteralSelf() throws {
		struct Wrapper: Codable {
			let key: Atproto.LiteralSelfRecordKey
		}
		let expected =
			"""
			{"key":"self"}
			"""
		let _ = try JSONDecoder().decode(
			Wrapper.self,
			from: expected.utf8Data
		)

		let broken =
			"""
			{"key":"sel"}
			"""
		#expect(throws: (any Error).self) {
			let _ = try JSONDecoder().decode(
				Wrapper.self,
				from: broken.utf8Data
			)
		}

		let output = try JSONEncoder().encode(Wrapper(key: .init()))
		#expect(
			String(data: output, encoding: .utf8)?
				.trimmingCharacters(in: .whitespacesAndNewlines)
				== expected
				.trimmingCharacters(in: .whitespacesAndNewlines)
		)

	}

	@Test func testNSID() throws {
		struct Wrapper: Codable {
			let nsid: Atproto.NSID
		}

		let nsid = "com.example.declaration"
		let expected =
			"""
			{"nsid":"\(nsid)"}
			"""

		let decoded = try JSONDecoder().decode(
			Wrapper.self,
			from: expected.utf8Data
		)

		#expect(decoded.nsid.rawValue == nsid)

		let output = try JSONEncoder().encode(
			Wrapper(nsid: .init(string: nsid))
		)
		#expect(
			String(data: output, encoding: .utf8)?
				.trimmingCharacters(in: .whitespacesAndNewlines)
				== expected
				.trimmingCharacters(in: .whitespacesAndNewlines)
		)
	}
}
