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

/// A miss on a read-if-present endpoint: the reference PDS sends a 400, tranquil
/// a 404. Run through the real `GetRecord` so the constrained default is the one
/// its conformance picks up.
struct NotFoundParsingTests {
	private typealias GetRecord = Lexicon.Com.Atproto.Repo.GetRecord<
		PutRecordSwapEncodingTests.Thing
	>

	private func parse(_ status: Int, _ body: String) throws
		-> Atproto.XRPC.ParsedResponse<GetRecord.Output>
	{
		try GetRecord.parse(
			fullResponse: HTTPDataResponse(
				data: Data(body.utf8), response: .init(status: .init(code: status)))
		)
	}

	@Test func notFoundCodeOn404IsTyped() throws {
		let parsed = try parse(
			404, #"{"error":"RecordNotFound","message":"Record not found"}"#)
		guard case .error(.xrpcError(let status, let error)) = parsed else {
			Issue.record("expected .xrpcError, got \(parsed)")
			return
		}
		#expect(status == .notFound)
		#expect(error.error == "RecordNotFound")
	}

	@Test func notFoundCodeOn400IsStillTyped() throws {
		let parsed = try parse(
			400, #"{"error":"RecordNotFound","message":"Could not locate record"}"#)
		guard case .error(.xrpcError(let status, _)) = parsed else {
			Issue.record("expected .xrpcError, got \(parsed)")
			return
		}
		#expect(status == .badRequest)
	}

	@Test func otherErrorOn404StaysUnrecognized() throws {
		let parsed = try parse(404, #"{"error":"RepoNotFound","message":"Repo not found"}"#)
		guard case .error(.unrecognized) = parsed else {
			Issue.record("expected .unrecognized, got \(parsed)")
			return
		}
	}

	@Test func nonXRPC404StaysUnrecognized() throws {
		let parsed = try parse(404, "<html>Not Found</html>")
		guard case .error(.unrecognized) = parsed else {
			Issue.record("expected .unrecognized, got \(parsed)")
			return
		}
	}

	@Test func endpointWithoutNotFoundCodesIgnores404Body() throws {
		let parsed = try Lexicon.Com.Atproto.Repo.PutRecord<
			PutRecordSwapEncodingTests.Thing
		>
		.parse(
			fullResponse: HTTPDataResponse(
				data: Data(#"{"error":"RecordNotFound"}"#.utf8),
				response: .init(status: .notFound)))
		guard case .error(.unrecognized) = parsed else {
			Issue.record("expected .unrecognized, got \(parsed)")
			return
		}
	}
}
