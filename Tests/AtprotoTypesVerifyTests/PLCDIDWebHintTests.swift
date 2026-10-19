//
//  PLCDIDWebHintTests.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 10/18/26.
//

import AtprotoTypes
import AtprotoTypesVerify
import AtprotoTypesVerifyMocks
import Foundation
import Testing

@Suite("did:web documents are hints")
struct PLCDIDWebHintTests {
	///A `did:web` document has no log behind it to check, so the most that can
	///be said about one is that a relay asserted it. The verifier refuses the
	///DID rather than rendering anything, and the only type a `did:web`
	///document can be carried in is the one that says so.
	@Test
	func aDidWebDocumentIsNeverReturnedAsVerified() throws {
		let document = try JSONDecoder().decode(
			Atproto.DIDDocument.self,
			from: Data(#"{"id":"did:web:example.com"}"#.utf8)
		)
		let did = try Atproto.DID(string: "did:web:example.com")
		let hint = Atproto.PLC.Hint(did: did, document: document)
		#expect(hint.document.id == "did:web:example.com")

		// The log served is a well-formed one, so the DID's method is the only
		// thing that can refuse it. An empty list would let a verifier that
		// rules on emptiness first fail this test while the property still
		// held.
		let scenario = PLCScenario()
		let entry = try PLCFixture.entry(try scenario.signed(prev: nil))

		#expect {
			_ = try Atproto.PLC.Verifier().verifyLog(did: did, entries: [entry])
		} throws: { isCase("notAPlcDID")($0) }
	}
}
