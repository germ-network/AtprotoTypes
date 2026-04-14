//
//  AtprotoDIDTests.swift
//  SwiftAtprotoOAuth
//
//  Created by Mark @ Germ on 2/17/26.
//

import AtprotoTypes
import Foundation
import Testing

struct AtprotoDIDTests {
	@Test func testParse() throws {
		#expect(try Atproto.DID(rawValue: "di:plc:example.com") == nil)

		#expect(try Atproto.DID(rawValue: "did:method:example.com") == nil)
	}

	struct Wrapper: Codable {
		let did: Atproto.DID
	}
	static let exampleDidString = "did:plc:example.com"

	@Test func testDirectDecoding() throws {
		let raw = "{ \"did\": \"\(Self.exampleDidString)\" }"

		let decoded = try JSONDecoder().decode(Wrapper.self, from: Data(raw.utf8))

		#expect(decoded.did.rawValue == Self.exampleDidString)
	}

	@Test func testDirectEncoding() throws {
		struct Wrapper: Codable {
			let did: Atproto.DID
		}
		let wrapped = try Wrapper(
			did: .init(rawValue: Self.exampleDidString).tryUnwrap
		)
		let encoded = try JSONEncoder().encode(wrapped)
		let decoded = try JSONSerialization.jsonObject(with: encoded)

		let typedDecoded = try #require(decoded as? [String: String])
		#expect(typedDecoded["did"] == Self.exampleDidString)

	}

}
