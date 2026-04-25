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
		
		let output = try JSONEncoder().encode(Wrapper(key: .init()))
		#expect(
			String(data: output, encoding: .utf8)?
				.trimmingCharacters(in: .whitespacesAndNewlines) == expected
				.trimmingCharacters(in: .whitespacesAndNewlines)
		)
		
	}
}
