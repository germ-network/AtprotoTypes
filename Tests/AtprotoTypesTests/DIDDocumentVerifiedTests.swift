//
//  DIDDocumentVerifiedTests.swift
//  AtprotoTypesTests
//

import AtprotoTypes
import Foundation
import Testing

@Suite struct DIDDocumentVerifiedTests {
	private func document(id: String, alsoKnownAs: [String]? = nil) -> Atproto.DIDDocument {
		.init(id: id, alsoKnownAs: alsoKnownAs)
	}

	// MARK: - Synchronous overload

	@Test func mismatchedDidThrows() throws {
		let document = document(id: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaaaa")
		let requested = try Atproto.DID(string: "did:plc:bbbbbbbbbbbbbbbbbbbbbbbbbb")
		#expect(
			throws: Atproto.DIDDocument.Errors.documentIdMismatch(
				requested: requested.rawValue,
				returned: document.id
			)
		) {
			try document.verified(expecting: .invalid, did: requested)
		}
	}

	@Test func matchingDidAndHandleVerifies() throws {
		let did = try Atproto.DID(string: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaaaa")
		let handle = try Atproto.Handle(string: "alice.example.com")
		let document = document(id: did.rawValue, alsoKnownAs: ["at://alice.example.com"])

		let verified = try document.verified(expecting: handle, did: did)
		#expect(verified.did == did)
		#expect(verified.verifiedHandle == handle)
	}

	/// A handle mismatch degrades to `.invalid` rather than throwing —
	/// deliberately asymmetric with the DID check above.
	@Test func matchingDidButMismatchedHandleDegradesRatherThanThrows() throws {
		let did = try Atproto.DID(string: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaaaa")
		let expected = try Atproto.Handle(string: "alice.example.com")
		let document = document(
			id: did.rawValue, alsoKnownAs: ["at://someone-else.example.com"])

		let verified = try document.verified(expecting: expected, did: did)
		#expect(verified.did == did)
		#expect(verified.verifiedHandle == .invalid)
	}

	@Test func matchingDidWithNoAlsoKnownAsDegrades() throws {
		let did = try Atproto.DID(string: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaaaa")
		let document = document(id: did.rawValue, alsoKnownAs: nil)

		let verified = try document.verified(
			expecting: try Atproto.Handle(string: "alice.example.com"),
			did: did
		)
		#expect(verified.verifiedHandle == .invalid)
	}

	/// Pins that the rename off the shadowed `did` local didn't disturb the
	/// DID-parse failure path.
	@Test func aNonDidIdStillThrowsDIDParseErrors() throws {
		let document = document(id: "not-a-did")
		#expect(throws: Atproto.DID.Errors.invalidPrefix) {
			try document.verified(
				expecting: .invalid,
				did: try Atproto.DID(string: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaaaa")
			)
		}
	}

	// MARK: - Async overload

	@Test func asyncOverloadWithNoExpectedDidSkipsTheCheck() async throws {
		let document = document(id: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaaaa", alsoKnownAs: nil)
		// No expectedDid supplied — matches the pre-fix behavior exactly, for
		// callers with no DID to compare against yet.
		let verified = try await document.verified { _ in
			try Atproto.DID(string: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaaaa")
		}
		#expect(verified.verifiedHandle == .invalid)
	}

	@Test func asyncOverloadWithMismatchedExpectedDidThrows() async throws {
		let document = document(id: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaaaa")
		let requested = try Atproto.DID(string: "did:plc:bbbbbbbbbbbbbbbbbbbbbbbbbb")
		await #expect(
			throws: Atproto.DIDDocument.Errors.documentIdMismatch(
				requested: requested.rawValue,
				returned: document.id
			)
		) {
			try await document.verified(expectedDid: requested) { _ in requested }
		}
	}

	@Test func asyncOverloadWithMatchingExpectedDidVerifies() async throws {
		let did = try Atproto.DID(string: "did:plc:aaaaaaaaaaaaaaaaaaaaaaaaaa")
		let handle = try Atproto.Handle(string: "alice.example.com")
		let document = document(id: did.rawValue, alsoKnownAs: ["at://alice.example.com"])

		let verified = try await document.verified(expectedDid: did) { _ in did }
		#expect(verified.did == did)
		#expect(verified.verifiedHandle == handle)
	}
}
