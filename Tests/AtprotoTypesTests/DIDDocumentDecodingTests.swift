//
//  DIDDocumentDecodingTests.swift
//  AtprotoTypesTests
//

import AtprotoTypes
import AtprotoTypesMocks
import Foundation
import Testing

@Suite struct DIDDocumentDecodingTests {
	private func decode(_ json: String) throws -> Atproto.DIDDocument {
		try JSONDecoder().decode(Atproto.DIDDocument.self, from: Data(json.utf8))
	}

	// MARK: - The shape a real, self-hosted did:web document may take

	@Test func aMinimalDidWebDocumentDecodes() throws {
		let document = try decode(
			"""
			{"@context": "https://www.w3.org/ns/did/v1", "id": "did:web:example.com"}
			"""
		)
		#expect(document.context == ["https://www.w3.org/ns/did/v1"])
		#expect(document.id == "did:web:example.com")
		#expect(document.verificationMethod == nil)
		#expect(document.service == nil)
	}

	@Test func contextAsAnArrayIsPreserved() throws {
		let document = try decode(
			"""
			{"@context": ["https://www.w3.org/ns/did/v1", "https://w3id.org/security/v1"], "id": "did:web:example.com"}
			"""
		)
		#expect(
			document.context == [
				"https://www.w3.org/ns/did/v1", "https://w3id.org/security/v1",
			])
	}

	@Test func absentContextDecodesToNil() throws {
		let document = try decode(#"{"id": "did:web:example.com"}"#)
		#expect(document.context == nil)
	}

	/// Deliberately lenient, not a decode error — see the doc comment on
	/// `DIDDocument.init(from:)`. Pinned so a future refactor can't flip this
	/// silently either direction.
	@Test(arguments: ["42", "null", "true", "{\"x\": 1}", "[\"a\", 5]"])
	func aContextThatsNeitherStringNorStringArrayDecodesToNil(
		_ contextJSON: String
	) throws {
		let document = try decode(
			#"{"@context": \#(contextJSON), "id": "did:web:example.com"}"#
		)
		#expect(document.context == nil)
	}

	@Test func aPublicKeyJwkOnlyVerificationMethodDecodesWithNilMultibase() throws {
		let document = try decode(
			"""
			{
			  "id": "did:web:example.com",
			  "verificationMethod": [{
			    "id": "did:web:example.com#atproto",
			    "type": "JsonWebKey2020",
			    "controller": "did:web:example.com"
			  }]
			}
			"""
		)
		let method = try #require(document.verificationMethod?.first)
		#expect(method.publicKeyMultibase == nil)
	}

	@Test func absentServiceDecodesToNilAndPdsUrlThrowsMissingServiceUrl() throws {
		let document = try decode(#"{"id": "did:web:example.com"}"#)
		#expect(document.service == nil)
		#expect(throws: Atproto.DIDDocument.Errors.missingServiceUrl) {
			try document.pdsUrl
		}
	}

	/// The canonical schema permits an object-shaped `serviceEndpoint`; this
	/// type never stores one (nothing upstream treats it as usable either —
	/// see the property's doc comment). The entry survives decode with a
	/// `nil` endpoint rather than failing the whole document, and
	/// `checkServiceForAtproto` throws on it rather than searching past it,
	/// matching "the first matching entry should be used, any others
	/// ignored."
	@Test func anObjectShapedServiceEndpointDecodesToANilURL() throws {
		let document = try decode(
			"""
			{
			  "id": "did:web:example.com",
			  "service": [{
			    "id": "#atproto_pds",
			    "type": "AtprotoPersonalDataServer",
			    "serviceEndpoint": {"uri": "https://pds.example.com"}
			  }]
			}
			"""
		)
		#expect(document.service?.first?.serviceEndpoint == nil)
		#expect(throws: Atproto.DIDDocument.Errors.missingServiceUrl) {
			try document.checkServiceForAtproto()
		}
	}

	/// Same leniency as `@context`, and same reasoning: `serviceEndpoint`
	/// fails sanely at use (`missingServiceUrl`) rather than failing the
	/// whole document at decode.
	@Test(arguments: ["42", "null", "true"])
	func aServiceEndpointThatsNeitherStringNorObjectDecodesToNil(
		_ endpointJSON: String
	) throws {
		let document = try decode(
			"""
			{"id": "did:web:example.com", "service": [{"id": "#atproto_pds", \
			"type": "AtprotoPersonalDataServer", "serviceEndpoint": \(endpointJSON)}]}
			"""
		)
		#expect(document.service?.first?.serviceEndpoint == nil)
	}

	// MARK: - Regression: the uniform PLC shape must keep decoding exactly as before

	@Test func aFullPLCShapedDocumentStillDecodesEveryField() throws {
		// A real plc.directory-shaped payload, decoded — not just the mock's
		// memberwise construction, which would pass even if decoding broke.
		let document = try decode(
			"""
			{
			  "@context": ["https://www.w3.org/ns/did/v1"],
			  "id": "did:plc:4yvwfwxfz5sney4twepuzdu7",
			  "alsoKnownAs": ["at://example.com"],
			  "verificationMethod": [{
			    "id": "did:plc:4yvwfwxfz5sney4twepuzdu7#atproto",
			    "type": "Multikey",
			    "controller": "did:plc:4yvwfwxfz5sney4twepuzdu7",
			    "publicKeyMultibase": "zQ3shPrWRUXva2mWziWZt1vrjuXUx3E28WfgsAwStMcAmDt93"
			  }],
			  "service": [{
			    "id": "#atproto_pds",
			    "type": "AtprotoPersonalDataServer",
			    "serviceEndpoint": "https://blusher.us-east.host.bsky.network"
			  }]
			}
			"""
		)
		#expect(document.context?.isEmpty == false)
		#expect(document.verificationMethod?.first?.publicKeyMultibase != nil)
		#expect(document.service?.first?.serviceEndpoint != nil)
		#expect(try document.pdsUrl.host() == "blusher.us-east.host.bsky.network")
	}

	@Test func theMockDocumentRoundTripsThroughEncodeAndDecode() throws {
		let original = try Atproto.DIDDocument.mock()
		let data = try JSONEncoder().encode(original)
		let decoded = try JSONDecoder().decode(Atproto.DIDDocument.self, from: data)
		#expect(decoded == original)
	}
}
