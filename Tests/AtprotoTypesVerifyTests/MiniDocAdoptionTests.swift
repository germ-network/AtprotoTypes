//
//  MiniDocAdoptionTests.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 9/7/26.
//

import AtprotoTypes
import AtprotoTypesVerify
import AtprotoTypesVerifyMocks
import Crypto
import Foundation
import Testing

///The success counterpart to `RepoProofVerifierTests`' identity-plumbing
///refusals: a DID document carrying the `#atproto` method that a resolver's
///miniDoc adapter (Slingshot's `resolveMiniDoc`) and plc.directory both publish
///yields a signing key `RepoSigningKey(atprotoKeyIn:)` accepts. Pins that
///parse-success property in the module that owns `RepoSigningKey`. GER-2268.
@Suite("miniDoc adoption")
struct MiniDocAdoptionTests {
	///The issue's literal verification requirement: a miniDoc-shaped document
	///resolved to a `DIDDocument.Verified` whose `verificationMethod` still carries
	///the `#atproto` key, which `RepoSigningKey(atprotoKeyIn:did:)` then parses. A
	///P-256 fixture, as the issue asked — swift-crypto backs that curve directly
	///(secp256k1's success path is exercised where the k256 port lives).
	@Test("a P-256 #atproto method resolves to a key RepoSigningKey accepts")
	func p256SigningKeyParsesThroughVerified() throws {
		let signing = P256.Signing.PrivateKey()
		let document = try RepoFixture.document(
			did: RepoFixture.did, key: signing.publicKey)

		//`.verified(...)` hands back `document: self` unchanged, so this pins that
		//the resolved document still carries the method downstream — the property
		//GER-2268 restored (the pre-fix Slingshot path handed the verifier `[]`).
		//The fixture's empty `alsoKnownAs` degrades the handle to `.invalid`
		//regardless of what is passed here, so `expecting:` is a don't-care.
		let verified = try document.verified(expecting: .invalid, did: RepoFixture.did)
		_ = try #require(
			verified.document.verificationMethod?.first { $0.id.hasSuffix("#atproto") })

		let key = try RepoSigningKey(atprotoKeyIn: verified.document, did: verified.did)
		#expect(key.curve == .p256)
		//round-trips the exact published key, not merely "some key parsed"
		#expect(key.compressedPoint == signing.publicKey.compressedRepresentation)
	}

	///A method id may be a bare `#atproto` fragment rather than the fully-qualified
	///`did:...#atproto` that every fixture and both real emitters use; this pins
	///that such a document still resolves its key. Built through the public
	///`DIDDocument`/`VerificationMethod` initialisers GER-2268 opened up.
	@Test("a bare `#atproto` fragment id is accepted, not only the fully-qualified form")
	func bareAtprotoFragmentParses() throws {
		let signing = P256.Signing.PrivateKey()
		let document = Atproto.DIDDocument(
			id: RepoFixture.did.rawValue,
			alsoKnownAs: nil,
			verificationMethod: [
				.init(
					id: "#atproto",
					type: "Multikey",
					controller: RepoFixture.did.rawValue,
					publicKeyMultibase: RepoFixture.multibase(signing.publicKey)
				)
			]
		)

		let key = try RepoSigningKey(atprotoKeyIn: document, did: RepoFixture.did)
		#expect(key.curve == .p256)
		#expect(key.compressedPoint == signing.publicKey.compressedRepresentation)
	}
}
