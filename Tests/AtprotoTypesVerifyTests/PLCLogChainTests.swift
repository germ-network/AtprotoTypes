//
//  PLCLogChainTests.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 10/18/26.
//

import AtprotoTypes
import AtprotoTypesVerify
import AtprotoTypesVerifyMocks
import Crypto
import Foundation
import Testing

@Suite("did:plc log chain")
struct PLCLogChainTests {
	///Every live operation's `prev` is the CID of the live operation before it,
	///and the chain runs from the genesis to the last live operation.
	@Test
	func thePrevChainLinksEveryLiveOperation() throws {
		for name in PLCVector.names {
			let vector = try PLCVector.load(name)
			let verified = try Atproto.PLC.Verifier().verifyLog(
				did: vector.did, entries: vector.entries)
			#expect(verified.did == vector.did)
		}
	}

	///An operation is signed by a key the *previous* operation established, not
	///by one of its own. The `key-rotation` vector is the case that tells the
	///two apart: that operation changes its `rotationKeys`, and its own set does
	///not verify it.
	@Test
	func anOperationVerifiesUnderThePreviousOperationsRotationKeys() throws {
		let vector = try PLCVector.load(PLCVector.keyRotation)
		let verified = try Atproto.PLC.Verifier().verifyLog(
			did: vector.did, entries: vector.entries)
		#expect(verified.did == vector.did)
	}

	///The same rule, from the other side: an operation that rotates to a key the
	///log never established and signs with it is refused. Under "the previous
	///operation's keys" that is a forgery; under "its own keys" it would pass,
	///which is the whole of the difference between the two readings.
	@Test
	func anOperationSignedByItsOwnNewRotationKeyIsRefused() throws {
		let scenario = PLCScenario()
		let genesis = try scenario.signed(prev: nil)
		let did = try PLCFixture.genesisDID(genesis)

		let replacement = P256.Signing.PrivateKey()
		let newKey = PLCFixture.didKey(replacement.publicKey)
		let update = try PLCFixture.signed(
			PLCFixture.unsignedOperation(
				rotationKeys: [newKey],
				verificationMethods: [(key: "atproto", value: newKey)],
				alsoKnownAs: ["at://example.test"],
				services: scenario.services,
				prev: try PLCFixture.cid(genesis)
			),
			with: replacement
		)

		#expect {
			_ = try Atproto.PLC.Verifier().verifyLog(
				did: did,
				entries: [
					try PLCFixture.entry(genesis), try PLCFixture.entry(update),
				]
			)
		} throws: { isCase("noRotationKeyVerifiedTheSignature")($0) }
	}

	///A live operation pointing at an operation the log does not contain is
	///refused, though every CID in it is self-consistent and its signature
	///verifies — a truncated log is a truncation, but a re-pointed one is a
	///forgery.
	@Test
	func aBrokenPrevIsRefused() throws {
		let scenario = PLCScenario()
		let genesis = try scenario.signed(prev: nil)
		let did = try PLCFixture.genesisDID(genesis)

		// Two operations chained off the genesis; the log serves only the
		// second, so its `prev` names an operation that is not there.
		let orphan = try scenario.signed(prev: try PLCFixture.cid(genesis))
		let update = try scenario.signed(prev: try PLCFixture.cid(orphan))

		#expect {
			_ = try Atproto.PLC.Verifier().verifyLog(
				did: did,
				entries: [
					try PLCFixture.entry(genesis), try PLCFixture.entry(update),
				]
			)
		} throws: { isCase("chainBroken")($0) }
	}

	///A signature from a key the log never established is refused. Every other
	///byte of the operation is honest and its CID matches, so nothing but the
	///signature check can catch it.
	@Test
	func aForgedSignatureIsRefused() throws {
		let scenario = PLCScenario()
		let unsigned = scenario.unsigned(prev: nil)
		let attacker = P256.Signing.PrivateKey()
		let forged = RepoFixture.lowS(
			try attacker.signature(for: DAGCBOREncoder.encode(unsigned))
				.rawRepresentation)

		let signed = try PLCFixture.signed(unsigned, with: scenario.signer, sig: forged)
		let did = try PLCFixture.genesisDID(signed)

		#expect {
			_ = try Atproto.PLC.Verifier().verifyLog(
				did: did, entries: [try PLCFixture.entry(signed)])
		} throws: { isCase("noRotationKeyVerifiedTheSignature")($0) }
	}

	///A high-S twin of a valid signature is refused, and for its own reason: it
	///is a second spelling of one signature, so accepting it would let an
	///operation's CID change without invalidating the signature.
	@Test
	func aHighSSignatureIsRefused() throws {
		let scenario = PLCScenario()
		let unsigned = scenario.unsigned(prev: nil)
		let valid = try scenario.signer.signature(
			for: DAGCBOREncoder.encode(unsigned)
		).rawRepresentation

		let signed = try PLCFixture.signed(
			unsigned, with: scenario.signer, sig: RepoFixture.highS(valid))
		let did = try PLCFixture.genesisDID(signed)

		#expect {
			_ = try Atproto.PLC.Verifier().verifyLog(
				did: did, entries: [try PLCFixture.entry(signed)])
		} throws: { isCase("nonCanonicalSignature")($0) }
	}

	///An entry whose claimed CID is not the CID of the operation it carries is
	///refused. The operation is untouched, its signature holds, and its `prev`
	///is honest — so unless the verifier recomputes the CID rather than
	///believing the log, nothing catches this.
	@Test
	func aLogWhoseEntryCIDDoesNotMatchItsOperationIsRefused() throws {
		let scenario = PLCScenario()
		let genesis = try scenario.signed(prev: nil)
		let did = try PLCFixture.genesisDID(genesis)
		let honest = try PLCFixture.entry(genesis)

		let forged = try Atproto.PLC.LogEntry(
			cid: "bafyreieibu2mtgsovktnswo6l7dv4i4ztioutzpsy7wsasmbznzqxkpyje",
			operationJSON: honest.operationJSON,
			nullified: false
		)

		#expect {
			_ = try Atproto.PLC.Verifier().verifyLog(did: did, entries: [forged])
		} throws: { isCase("cidMismatch")($0) }
	}

	///A nullified operation is not part of the live chain, so the chain runs
	///through it rather than over it. Two operations share the genesis as their
	///`prev` — a fork the directory has already ruled against — and the
	///document has to come from the live one.
	@Test
	func aNullifiedForkOperationIsSkippedByTheLiveChain() throws {
		let scenario = PLCScenario()
		let genesis = try scenario.signed(prev: nil)
		let did = try PLCFixture.genesisDID(genesis)
		let genesisCID = try PLCFixture.cid(genesis)

		func fork(handle: String) throws -> DAGCBORValue {
			try PLCFixture.signed(
				PLCFixture.unsignedOperation(
					rotationKeys: [scenario.rotationKey],
					verificationMethods: [
						(key: "atproto", value: scenario.rotationKey)
					],
					alsoKnownAs: [handle],
					services: scenario.services,
					prev: genesisCID
				),
				with: scenario.signer
			)
		}

		let abandoned = try PLCFixture.entry(
			try fork(handle: "at://abandoned.test"), nullified: true)
		let live = try PLCFixture.entry(try fork(handle: "at://live.test"))

		let verified = try Atproto.PLC.Verifier().verifyLog(
			did: did,
			entries: [try PLCFixture.entry(genesis), abandoned, live]
		)
		#expect(verified.document.alsoKnownAs == ["at://live.test"])
	}

	///The genesis cannot be nullified: it is what the DID is the hash of, so a
	///log that disowns it disowns the identifier it is claimed for.
	@Test
	func aNullifiedGenesisIsRefused() throws {
		let scenario = PLCScenario()
		let genesis = try scenario.signed(prev: nil)
		let did = try PLCFixture.genesisDID(genesis)
		let entry = try PLCFixture.entry(genesis, nullified: true)

		#expect {
			_ = try Atproto.PLC.Verifier().verifyLog(did: did, entries: [entry])
		} throws: { isCase("genesisIsNullified")($0) }
	}

	///A rotation key the method specification does not permit is refused. Only
	///secp256k1 and P-256 are allowed there, and they must be serialized as
	///`did:key` — the asymmetry with a verification-method key, which may be any
	///syntactically valid `did:key` and is therefore not parsed into a key type
	///at all.
	@Test
	func aRotationKeyTheMethodSpecificationDoesNotPermitIsRefused() throws {
		let scenario = PLCScenario()
		let ed25519 = "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK"
		// The scenario's own P-256 key with the `did:key:` prefix dropped:
		// a multibase string, which is not the serialization the method
		// specification gives a rotation key, though the key parser would take
		// it (it accepts a bare multibase for the repo path, where a document
		// publishes one).
		let bareMultibase = String(scenario.rotationKey.dropFirst("did:key:".count))

		for key in [ed25519, bareMultibase] {
			let genesis = try scenario.signed(rotationKeys: [key], prev: nil)
			let did = try PLCFixture.genesisDID(genesis)
			#expect {
				_ = try Atproto.PLC.Verifier().verifyLog(
					did: did, entries: [try PLCFixture.entry(genesis)])
			} throws: { isCase("badRotationKey")($0) }
		}
	}
}
