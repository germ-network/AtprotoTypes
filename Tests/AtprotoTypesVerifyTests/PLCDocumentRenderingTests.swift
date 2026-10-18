//
//  PLCDocumentRenderingTests.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 10/18/26.
//

import AtprotoTypes
import AtprotoTypesVerifyMocks
import Crypto
import Foundation
import Testing

@testable import AtprotoTypesVerify

@Suite("did:plc document rendering")
struct PLCDocumentRenderingTests {
	///A verified log renders the document the directory serves — which is what
	///a device checks a served document against, and what makes the check
	///worth doing.
	@Test
	func aCurrentFormatDIDRendersTheDirectorysDocument() throws {
		let vector = try PLCVector.load(PLCVector.currentFormat)
		let verified = try Atproto.PLC.Verifier().verifyLog(
			did: vector.did, entries: vector.entries)
		#expect(verified.document == vector.document)
	}

	///The same, through a log whose genesis is a legacy `create`: the DID is
	///derived from the unconverted bytes, and the log verifies and renders the
	///directory's document. The document itself comes from a later regular
	///operation — this vector's `create` is not its last live operation — so the
	///conversion is pinned directly by
	///``aLegacyCreateGenesisConvertsToTheDirectorysDocument`` instead.
	@Test
	func aLegacyGenesisDIDRendersTheDirectorysDocument() throws {
		let vector = try PLCVector.load(PLCVector.legacyGenesis)
		let verified = try Atproto.PLC.Verifier().verifyLog(
			did: vector.did, entries: vector.entries)
		#expect(verified.document == vector.document)
	}

	///The legacy `create` conversion itself, which no captured log observes: a
	///`create` only renders when it is the last live operation, and the one
	///legacy-genesis vector has seven regular operations after its genesis.
	///
	///The two keys are of different curves, so the order the conversion puts
	///them in — recovery first, signing second — is observable. Both are real
	///`did:key` strings: the secp256k1 one from the captured vectors, the P-256
	///one from the method specification's own example.
	@Test
	func aLegacyCreateGenesisConvertsToTheDirectorysDocument() throws {
		let did = try Atproto.DID(string: "did:plc:ewvi7nxzyoun6zhxrhs64oiz")
		let recoveryKey = "did:key:zQ3shhCGUqDKjStzuDxPkTxN6ujddP4RkEKJJouJGRRkaLGbg"
		let signingKey = "did:key:zDnaeh9v2RmcMo13Du2d6pjUf5bZwtauYxj3n9dYjw4EZUAR7"

		let json = """
			{"type":"create","signingKey":"\(signingKey)",\
			"recoveryKey":"\(recoveryKey)","handle":"example.test",\
			"service":"https://pds.example.test","prev":null,"sig":""}
			"""
		let operation = try Atproto.PLC.Operation.parse(json: json)
		#expect(operation.rotationKeys.map(\.curve) == [.secp256k1, .p256])

		let document = try Atproto.PLC.DocumentRenderer.render(
			did: did, operation: operation)
		#expect(document.alsoKnownAs == ["at://example.test"])
		#expect(document.verificationMethod?.count == 1)
		#expect(document.verificationMethod?.first?.id == "\(did.rawValue)#atproto")
		#expect(
			document.verificationMethod?.first?.publicKeyMultibase
				== signingKey.dropFirst("did:key:".count).description)
		//only the verification-method key contributes a suite — the recovery
		//key is a rotation key and does not appear in the document
		#expect(
			document.context == [
				"https://www.w3.org/ns/did/v1",
				"https://w3id.org/security/multikey/v1",
				"https://w3id.org/security/suites/ecdsa-2019/v1",
			])
		#expect(document.service?.count == 1)
		#expect(document.service?.first?.id == "#atproto_pds")
		#expect(document.service?.first?.type == "AtprotoPersonalDataServer")
		#expect(
			document.service?.first?.serviceEndpoint
				== URL(string: "https://pds.example.test"))
	}

	///The `@context` names the curves of the keys the operation carries rather
	///than naming one fixed suite as the method specification's example does,
	///and omits the suite entry altogether when there is no key to describe.
	///
	///The secp256k1 branch is covered by the document-equality tests above,
	///whose vectors all carry `secp256k1-2019`; this pins the other branch and
	///the empty case, which no vector can (every P-256 `#atproto` key on the
	///directory belongs to one squatting campaign, so none was captured).
	@Test
	func theContextNamesTheCurvesOfTheKeysPresent() throws {
		let did = try Atproto.DID(string: "did:plc:ewvi7nxzyoun6zhxrhs64oiz")
		let rotationKey =
			"did:key:"
			+ RepoFixture.multibase(
				P256.Signing.PrivateKey().publicKey)

		let p256Key =
			"did:key:"
			+ RepoFixture.multibase(
				P256.Signing.PrivateKey().publicKey)
		let withP256 = try render(
			did: did,
			json: operationJSON(
				rotationKey: rotationKey,
				verificationMethods: #"{"atproto":"\#(p256Key)"}"#
			)
		)
		#expect(withP256.context?.last?.hasSuffix("ecdsa-2019/v1") == true)

		let withNone = try render(
			did: did,
			json: operationJSON(rotationKey: rotationKey, verificationMethods: "{}")
		)
		#expect(
			withNone.context == [
				"https://www.w3.org/ns/did/v1",
				"https://w3id.org/security/multikey/v1",
			])

		// A key the renderer has no suite for is still published as a
		// verification method — the method specification allows any
		// syntactically valid `did:key` there — and simply contributes no
		// context entry. The renderer therefore has to sniff the key itself
		// rather than parse it into a signing key, which would refuse it.
		let ed25519 = "did:key:z6MkhaXgBZDvotDkL5257faiztiGiC2QtKLGpbnnEGta2doK"
		let withUnknown = try render(
			did: did,
			json: operationJSON(
				rotationKey: rotationKey,
				verificationMethods: #"{"other":"\#(ed25519)"}"#
			)
		)
		#expect(withUnknown.verificationMethod?.count == 1)
		#expect(
			withUnknown.verificationMethod?.first?.publicKeyMultibase
				== ed25519.dropFirst("did:key:".count).description)
		#expect(
			withUnknown.context == [
				"https://www.w3.org/ns/did/v1",
				"https://w3id.org/security/multikey/v1",
			])
	}

	///A `plc_tombstone` ends the live chain, and the document it renders is the
	///cleared one: the tombstone removes every data field, so the DID keeps its
	///identifier and nothing else. No operation may follow it.
	@Test(.disabled("pending: tombstone through the fixture"))
	func aTombstoneEndsTheLogAndRendersTheClearedDocument() throws {
		let scenario = PLCScenario()
		let genesis = try scenario.signed(prev: nil)
		let did = try PLCFixture.genesisDID(genesis)
		let tombstone = try PLCFixture.signed(
			PLCFixture.unsignedTombstone(prev: try PLCFixture.cid(genesis)),
			with: scenario.signer
		)

		let verified = try Atproto.PLC.Verifier().verifyLog(
			did: did,
			entries: [try PLCFixture.entry(genesis), try PLCFixture.entry(tombstone)]
		)

		#expect(verified.document.id == did.rawValue)
		#expect(
			verified.document.context == [
				"https://www.w3.org/ns/did/v1",
				"https://w3id.org/security/multikey/v1",
			])
		#expect(verified.document.alsoKnownAs == [])
		#expect(verified.document.verificationMethod == [])
		#expect(verified.document.service == [])
	}

	///Nothing follows a tombstone. A deactivated DID cannot be updated, so a
	///live operation after one is a log the directory would never have
	///produced — and rendering it would resurrect the identifier.
	@Test(.disabled("pending: an operation after a tombstone, through the fixture"))
	func aLiveOperationAfterTheTombstoneIsRefused() throws {
		let scenario = PLCScenario()
		let genesis = try scenario.signed(prev: nil)
		let did = try PLCFixture.genesisDID(genesis)
		let tombstone = try PLCFixture.signed(
			PLCFixture.unsignedTombstone(prev: try PLCFixture.cid(genesis)),
			with: scenario.signer
		)
		let after = try scenario.signed(prev: try PLCFixture.cid(tombstone))

		#expect {
			_ = try Atproto.PLC.Verifier().verifyLog(
				did: did,
				entries: [
					try PLCFixture.entry(genesis),
					try PLCFixture.entry(tombstone),
					try PLCFixture.entry(after),
				]
			)
		} throws: { isCase("operationAfterTombstone")($0) }
	}

	// MARK: - Rendering one operation, without a whole log

	private func operationJSON(rotationKey: String, verificationMethods: String) -> String {
		"""
		{"type":"plc_operation","rotationKeys":["\(rotationKey)"],\
		"verificationMethods":\(verificationMethods),\
		"alsoKnownAs":["at://example.test"],\
		"services":{"atproto_pds":{"type":"AtprotoPersonalDataServer",\
		"endpoint":"https://example.test"}},"prev":null,"sig":""}
		"""
	}

	private func render(did: Atproto.DID, json: String) throws -> Atproto.DIDDocument {
		let operation = try Atproto.PLC.Operation.parse(json: json)
		return try Atproto.PLC.DocumentRenderer.render(did: did, operation: operation)
	}
}
