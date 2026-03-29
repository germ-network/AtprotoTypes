//
//  ProxyServiceTests.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 3/29/26.
//

import AtprotoTypes
import Foundation
import Testing

struct ProxyServiceTests {

	@Test func testEncode() throws {
		let proxy = ProxyService(
			did: .mock(method: .web),
			endpoint: UUID().uuidString
		)

		let parsed = try ProxyService(string: proxy.headerValue)
		#expect(parsed == proxy)
	}

	@Test func testDecodeFailures() throws {
		#expect(throws: AtprotoTypeError.invalidStringInput) {
			let _ = try ProxyService(string: "did:web:example.com#b#c")
		}

		#expect(throws: AtprotoDIDError.invalidPrefix) {
			let _ = try ProxyService(string: "a#b")
		}
	}
}
