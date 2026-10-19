//
//  PLCLogVerifyingTests.swift
//  AtprotoTypesTests
//
//  Created by Mark @ Germ on 10/18/26.
//

import AtprotoTypes
import Testing

@Suite("did:plc log verification seam")
struct PLCLogVerifyingTests {
	static let did = try! Atproto.DID(string: "did:plc:ewvi7nxzyoun6zhxrhs64oiz")

	///The whole point of the seam: a build that did not link the verifier must
	///refuse, never hand back something that merely looks like a verified
	///document.
	@Test func theUnavailableVerifierRefusesRatherThanPassingThrough() throws {
		let verifier = Atproto.PLC.LogUnavailable()
		#expect(throws: Atproto.PLC.Errors.verificationUnavailable) {
			_ = try verifier.verifyLog(
				did: Self.did,
				entries: [
					try Atproto.PLC.LogEntry(
						cid:
							"bafyreieibu2mtgsovktnswo6l7dv4i4ztioutzpsy7wsasmbznzqxkpyje",
						operationJSON:
							#"{"type":"plc_tombstone","prev":null,"sig":""}"#,
						nullified: false
					)
				]
			)
		}
	}

	///A claimed CID that is not in canonical form is refused while the claim is
	///still a string. `Atproto.CID` normalizes — its base32 decoder takes either
	///case — so a parsed value could not tell a canonical claim from an
	///equivalent spelling, and the log's claim is supposed to be the CID rather
	///than something that decodes to it.
	@Test func aNonCanonicalCIDIsRefused() throws {
		let canonical = "bafyreieibu2mtgsovktnswo6l7dv4i4ztioutzpsy7wsasmbznzqxkpyje"
		// The multibase prefix stays lower-case — `Atproto.CID` insists on that
		// much before the canonical check is even reached — while the base32
		// body is upper-cased, which its decoder accepts.
		let upperCased = "b" + canonical.dropFirst().uppercased()
		#expect(throws: Atproto.PLC.Errors.nonCanonicalCID(upperCased)) {
			_ = try Atproto.PLC.LogEntry(
				cid: upperCased,
				operationJSON: "{}",
				nullified: false
			)
		}
	}
}
