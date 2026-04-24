//
//  DatetimeTests.swift
//  AtprotoTypes
//
//  Created by Anna Mistele on 4/24/26.
//

import AtprotoTypes
import Testing

struct DatetimeTests {
	@Test func testDecode() async throws {
		let input = "2025-06-11T05:45:42.030Z"
		let parsed = Atproto.Datetime(rawValue: input)
		#expect(parsed != nil)
	}
}
