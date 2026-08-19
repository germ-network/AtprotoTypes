//
//  RepoProofVerifierTests.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import AtprotoTypesVerifyMocks
import Crypto
import Foundation
import Testing

@testable import AtprotoTypesVerify

@Suite("Repo proof")
struct RepoProofVerifierTests {
	static let path = Atproto.Repo.RecordPath(
		collection: .init(string: "com.germnetwork.declaration"),
		rkey: "self"
	)

	///One repo, assembled part by part so a test can replace exactly one piece
	///and watch the proof fail for that reason and no other.
	struct Scenario {
		let did: Atproto.DID
		let signing: P256.Signing.PrivateKey
		let record: DAGCBORValue

		init(
			did: Atproto.DID = RepoFixture.did,
			signing: P256.Signing.PrivateKey = P256.Signing.PrivateKey(),
			anchorKey: Data = Data(repeating: 0xA1, count: 32)
		) {
			self.did = did
			self.signing = signing
			self.record = RepoFixture.declaration(currentKey: anchorKey)
		}

		func car(
			commitDID: Atproto.DID? = nil,
			signedBy: P256.Signing.PrivateKey? = nil,
			mutateSignature: ((Data) -> Data)? = nil
		) throws -> Data {
			let recordBlock = try RepoFixture.block(record)
			let node = try RepoFixture.block(
				RepoFixture.node(
					entries: [
						(
							key: RepoProofVerifierTests.path.mstKey,
							value: recordBlock.cid
						)
					]
				)
			)
			var commit = try RepoFixture.commit(
				did: commitDID ?? did,
				dataRoot: node.cid,
				signedBy: signedBy ?? signing
			)
			if let mutateSignature, let existing = commit["sig"]?.bytesValue {
				commit = commit.removing(key: "sig")
				guard case .map(let fields) = commit else {
					fatalError("unreachable")
				}
				commit = .map(
					fields + [
						(
							key: "sig",
							value: .bytes(mutateSignature(existing))
						)
					]
				)
			}
			let commitBlock = try RepoFixture.block(commit)

			return RepoFixture.car(
				root: commitBlock.cid,
				blocks: [recordBlock, node, commitBlock]
			)
		}

		func document(
			key: P256.Signing.PublicKey? = nil
		) throws -> Atproto.DIDDocument {
			try RepoFixture.document(did: did, key: key ?? signing.publicKey)
		}
	}

	// MARK: - The path that should work

	@Test("a record in the repo verifies against the DID document's signing key")
	func verifiesGenuineRecord() throws {
		let scenario = Scenario()
		let proof = try Atproto.Repo.Verifier().verifyRecordProof(
			car: try scenario.car(),
			did: scenario.did,
			path: Self.path,
			document: try scenario.document()
		)

		#expect(proof.did == scenario.did)
		#expect(proof.path == Self.path)
		#expect(proof.block == DAGCBOREncoder.encode(scenario.record))
		#expect(proof.rev == "3lbwqrstuvwxy")
		//the returned CID is the one recomputed from the block
		#expect(
			try proof.cid.string
				== ContentIdentifier.compute(
					codec: .dagCBOR,
					block: proof.block
				).string
		)
	}

	// MARK: - The forgery the current code accepts

	///GER-2254's whole point. An internal-consistency check like
	///`verified(for:)` checks a declaration against its own `currentKey`, so an
	///attacker who mints a well-formed declaration with *their* anchor key and
	///binds it to a victim's DID passes that check — the record is internally
	///consistent, it just isn't the victim's. Provenance is what a JSON
	///`getRecord` throws away, and what these two cases restore.
	@Test("a declaration signed by the wrong key is refused")
	func rejectsForgedSigner() throws {
		let victim = Scenario()
		let attacker = P256.Signing.PrivateKey()

		//attacker's own declaration, in a repo they signed, claiming the
		//victim's DID in the commit
		let forged = Scenario(
			did: victim.did,
			signing: attacker,
			anchorKey: Data(repeating: 0xEE, count: 32)
		)

		#expect(throws: Atproto.Repo.ProofError.signatureDidNotVerify) {
			try Atproto.Repo.Verifier().verifyRecordProof(
				car: try forged.car(),
				did: victim.did,
				path: Self.path,
				//the victim's real DID document is the authority
				document: try victim.document()
			)
		}
	}

	@Test("a genuine repo belonging to someone else is refused")
	func rejectsSubstitutedRepo() throws {
		let victim = Scenario()
		let attacker = Scenario(
			did: RepoFixture.attacker,
			anchorKey: Data(repeating: 0xEE, count: 32)
		)

		//the attacker's repo is perfectly valid — it is just not the victim's
		#expect(
			throws: Atproto.Repo.ProofError.commitDIDMismatch(
				expected: victim.did.rawValue,
				found: RepoFixture.attacker.rawValue
			)
		) {
			try Atproto.Repo.Verifier().verifyRecordProof(
				car: try attacker.car(),
				did: victim.did,
				path: Self.path,
				document: try victim.document()
			)
		}
	}

	@Test("swapping the record bytes breaks the content address")
	func rejectsTamperedRecord() throws {
		let scenario = Scenario()
		var car = try scenario.car()

		//flip a byte inside the record block; the CAR's own CID check catches it
		let anchorByte = try #require(car.firstRange(of: Data([0xA1, 0xA1, 0xA1])))
		car[anchorByte.lowerBound] = 0xA2

		#expect(throws: (any Error).self) {
			try Atproto.Repo.Verifier().verifyRecordProof(
				car: car,
				did: scenario.did,
				path: Self.path,
				document: try scenario.document()
			)
		}
	}

	@Test("a document naming a different key refuses the proof")
	func rejectsWrongDocumentKey() throws {
		let scenario = Scenario()
		let unrelated = P256.Signing.PrivateKey()

		#expect(throws: Atproto.Repo.ProofError.signatureDidNotVerify) {
			try Atproto.Repo.Verifier().verifyRecordProof(
				car: try scenario.car(),
				did: scenario.did,
				path: Self.path,
				document: try scenario.document(key: unrelated.publicKey)
			)
		}
	}

	@Test("asking for a path the repo does not hold is refused")
	func rejectsAbsentPath() throws {
		let scenario = Scenario()

		#expect(throws: Atproto.Repo.ProofError.recordNotInTree) {
			try Atproto.Repo.Verifier().verifyRecordProof(
				car: try scenario.car(),
				did: scenario.did,
				path: .init(
					collection: .init(string: "com.germnetwork.declaration"),
					rkey: "notself"
				),
				document: try scenario.document()
			)
		}
	}

	// MARK: - Signature discipline

	///Without a low-S rule the same commit has two valid signatures, so two
	///distinct byte strings both "prove" it and a proof stops being a single
	///thing you can point at.
	@Test("the high-S twin of a valid signature is refused")
	func rejectsMalleatedSignature() throws {
		let scenario = Scenario()

		#expect(throws: Atproto.Repo.ProofError.nonCanonicalSignature) {
			try Atproto.Repo.Verifier().verifyRecordProof(
				car: try scenario.car(mutateSignature: RepoFixture.highS),
				did: scenario.did,
				path: Self.path,
				document: try scenario.document()
			)
		}
	}

	@Test("a signature of the wrong length is refused")
	func rejectsShortSignature() throws {
		let scenario = Scenario()

		#expect(throws: Atproto.Repo.ProofError.badSignatureLength(63)) {
			try Atproto.Repo.Verifier().verifyRecordProof(
				car: try scenario.car(mutateSignature: { $0.dropLast() }),
				did: scenario.did,
				path: Self.path,
				document: try scenario.document()
			)
		}
	}

	// MARK: - secp256k1

	///Mirrors `Scenario`, kept separate rather than adding a type parameter to
	///it: every other test in this file is p256-only and gains nothing from
	///carrying a curve around, and `Scenario`'s default-argument initialiser
	///(`Key = Key()`) doesn't generalize to an arbitrary `RepoFixtureSigningKey`.
	struct Secp256k1Scenario {
		let did: Atproto.DID
		let signer: Secp256k1TestSigner
		let record: DAGCBORValue

		init(
			did: Atproto.DID = RepoFixture.did,
			signer: Secp256k1TestSigner = Secp256k1TestSigner(),
			anchorKey: Data = Data(repeating: 0xA1, count: 32)
		) {
			self.did = did
			self.signer = signer
			self.record = RepoFixture.declaration(currentKey: anchorKey)
		}

		func car() throws -> Data {
			let recordBlock = try RepoFixture.block(record)
			let node = try RepoFixture.block(
				RepoFixture.node(
					entries: [
						(
							key: RepoProofVerifierTests.path.mstKey,
							value: recordBlock.cid
						)
					]
				)
			)
			let commit = try RepoFixture.commit(
				did: did, dataRoot: node.cid, signedBy: signer)
			let commitBlock = try RepoFixture.block(commit)
			return RepoFixture.car(
				root: commitBlock.cid, blocks: [recordBlock, node, commitBlock])
		}

		func document() throws -> Atproto.DIDDocument {
			try RepoFixture.document(did: did, key: signer.publicKey)
		}
	}

	///Most real Bluesky accounts sign with this curve, which is what made the
	///from-scratch verify-only port (Q-PMR-23) worth doing: a genuine k256
	///commit signature now verifies rather than failing closed.
	@Test("a genuine secp256k1 record verifies against the DID document's signing key")
	func verifiesGenuineSecp256k1Record() throws {
		let scenario = Secp256k1Scenario()
		let proof = try Atproto.Repo.Verifier().verifyRecordProof(
			car: try scenario.car(),
			did: scenario.did,
			path: Self.path,
			document: try scenario.document()
		)

		#expect(proof.did == scenario.did)
		#expect(proof.block == DAGCBOREncoder.encode(scenario.record))
	}

	@Test("a secp256k1 document naming a different key refuses the proof")
	func refusesWrongSecp256k1DocumentKey() throws {
		let scenario = Secp256k1Scenario()
		let unrelated = Secp256k1TestSigner()
		let document = try RepoFixture.document(did: scenario.did, key: unrelated.publicKey)

		#expect(throws: Atproto.Repo.ProofError.signatureDidNotVerify) {
			try Atproto.Repo.Verifier().verifyRecordProof(
				car: try scenario.car(),
				did: scenario.did,
				path: Self.path,
				document: document
			)
		}
	}

	// MARK: - Identity plumbing

	@Test("a document with no atproto verification method is refused")
	func refusesDocumentWithoutKey() throws {
		let scenario = Scenario()
		let document = try RepoFixture.document(did: scenario.did, methods: [])

		#expect(throws: Atproto.Repo.ProofError.noAtprotoSigningKey) {
			try Atproto.Repo.Verifier().verifyRecordProof(
				car: try scenario.car(),
				did: scenario.did,
				path: Self.path,
				document: document
			)
		}
	}

	///`verificationMethod` and `publicKeyMultibase` are both optional in the
	///canonical DID schema, so a document can omit either entirely. Absent has
	///to mean the same refusal as empty — these two cases are only reachable
	///by hand-written JSON, so without them the nil branches are decided by
	///whoever last touched the unwrap rather than by a test.
	@Test("a document omitting verificationMethod entirely is refused")
	func refusesDocumentWithNoVerificationMethodKey() throws {
		let scenario = Scenario()
		let document = try JSONDecoder().decode(
			Atproto.DIDDocument.self,
			from: Data(#"{"id":"\#(scenario.did.rawValue)"}"#.utf8)
		)

		#expect(throws: Atproto.Repo.ProofError.noAtprotoSigningKey) {
			try Atproto.Repo.Verifier().verifyRecordProof(
				car: try scenario.car(),
				did: scenario.did,
				path: Self.path,
				document: document
			)
		}
	}

	@Test("an atproto method publishing no key material is refused")
	func refusesMethodWithoutMultibase() throws {
		let scenario = Scenario()
		let json = """
			{"id":"\(scenario.did.rawValue)","verificationMethod":[\
			{"id":"\(scenario.did.rawValue)#atproto","type":"Multikey",\
			"controller":"\(scenario.did.rawValue)"}]}
			"""
		let document = try JSONDecoder().decode(
			Atproto.DIDDocument.self, from: Data(json.utf8))

		#expect(throws: Atproto.Repo.ProofError.noAtprotoSigningKey) {
			try Atproto.Repo.Verifier().verifyRecordProof(
				car: try scenario.car(),
				did: scenario.did,
				path: Self.path,
				document: document
			)
		}
	}

	///The gap this closes on the shipped fetch path: today's `resolveMiniDoc`
	///adapter builds a document with `verificationMethod: []`, so every proof
	///would stop here until that key is carried through.
	@Test("a document with only a non-atproto method is refused")
	func refusesWrongFragment() throws {
		let scenario = Scenario()
		let document = try RepoFixture.document(
			did: scenario.did,
			key: scenario.signing.publicKey,
			fragment: "#somethingElse"
		)

		#expect(throws: Atproto.Repo.ProofError.noAtprotoSigningKey) {
			try Atproto.Repo.Verifier().verifyRecordProof(
				car: try scenario.car(),
				did: scenario.did,
				path: Self.path,
				document: document
			)
		}
	}

	@Test("a signing key controlled by another DID is refused")
	func refusesForeignController() throws {
		let scenario = Scenario()
		let document = try RepoFixture.document(
			did: scenario.did,
			key: scenario.signing.publicKey,
			controller: RepoFixture.attacker.rawValue
		)

		#expect(throws: Atproto.Repo.ProofError.signingKeyControllerMismatch) {
			try Atproto.Repo.Verifier().verifyRecordProof(
				car: try scenario.car(),
				did: scenario.did,
				path: Self.path,
				document: document
			)
		}
	}

	///An empty `controller` means "self-controlled" (the DID document convention
	///for an absent field), not "skip the check" — otherwise a caller-side bug
	///pairing the wrong document with a `did` would pass silently whenever the
	///method simply omits the field, which is the common shape for real
	///documents. The document here is genuinely the attacker's own — correctly
	///self-controlled, with no explicit `controller` string at all — and must
	///still be refused when checked against the victim's `did`.
	@Test("an empty controller falls back to the document's own id, not a skip")
	func refusesEmptyControllerForWrongDID() throws {
		let scenario = Scenario()
		let document = try RepoFixture.document(
			did: RepoFixture.attacker,
			methods: [
				(
					id: RepoFixture.attacker.rawValue + "#atproto",
					controller: "",
					multibase: RepoFixture.multibase(scenario.signing.publicKey)
				)
			]
		)

		#expect(throws: Atproto.Repo.ProofError.signingKeyControllerMismatch) {
			try Atproto.Repo.Verifier().verifyRecordProof(
				car: try scenario.car(),
				did: scenario.did,
				path: Self.path,
				document: document
			)
		}
	}

	// MARK: - The space-constrained conformer

	@Test("the non-verifying conformer refuses rather than passing bytes through")
	func nonVerifyingConformerRefuses() throws {
		let scenario = Scenario()

		#expect(throws: Atproto.Repo.Errors.verificationUnavailable) {
			try Atproto.Repo.ProofUnavailable().verifyRecordProof(
				car: try scenario.car(),
				did: scenario.did,
				path: Self.path,
				document: try scenario.document()
			)
		}
	}
}
