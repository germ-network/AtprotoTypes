//
//  ResponseParsingTests.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 7/15/26.
//

import AtprotoTypes
import Foundation
import GermConvenience
import HTTPTypes
import Testing

struct ResponseParsingTests {
	private struct Body: Decodable, Sendable {
		let name: String
	}

	private enum MockParsing: Atproto.XRPC.ResponseParsing {
		typealias Output = Body
		static var badRequestErrors: Set<String> { defaultErrors }
	}

	//A 200 whose body fails to decode must keep the DecodingError (coding path
	//and all) rather than collapsing into .unrecognized, which reports nothing
	//beyond the response headers.
	@Test func undecodableBodyPreservesUnderlyingError() throws {
		let response = HTTPDataResponse(
			data: Data("{\"name\": 42}".utf8),
			response: .init(status: .ok)
		)

		let parsed = try MockParsing.parse(fullResponse: response)
		guard case .error(.undecodable(_, let underlying)) = parsed else {
			Issue.record("expected .undecodable, got \(parsed)")
			return
		}
		guard case DecodingError.typeMismatch(_, let context) = underlying else {
			Issue.record("expected DecodingError.typeMismatch, got \(underlying)")
			return
		}
		#expect(context.codingPath.map(\.stringValue) == ["name"])
	}

	//an unknown status without a decode attempt still reports .unrecognized
	@Test func unknownStatusReportsUnrecognized() throws {
		let response = HTTPDataResponse(
			data: Data(),
			response: .init(status: .init(code: 418))
		)

		let parsed = try MockParsing.parse(fullResponse: response)
		guard case .error(.unrecognized) = parsed else {
			Issue.record("expected .unrecognized, got \(parsed)")
			return
		}
	}
}
