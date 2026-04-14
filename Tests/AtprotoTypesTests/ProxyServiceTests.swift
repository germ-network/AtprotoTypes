//
//  ProxyServiceTests.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 3/29/26.
//

import AtprotoTypes
import Foundation
import Testing

@testable import GermConvenience

struct ProxyServiceTests {

	@Test func testEncode() throws {
		let proxy = Atproto.ProxyService(
			did: .mock(method: .web),
			endpoint: UUID().uuidString
		)

		let parsed = try Atproto.ProxyService(string: proxy.headerValue)
		#expect(parsed == proxy)
	}

	@Test func testDecodeFailures() throws {
		#expect(throws: Atproto.Errors.invalidStringInput) {
			let _ = try Atproto.ProxyService(string: "did:web:example.com#b#c")
		}

		#expect(throws: UnwrapError.missing("DID")) {
			let _ = try Atproto.ProxyService(string: "a#b")
		}
	}
}
