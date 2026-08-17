//
//  RepoProofVerifier.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import Foundation

extension Atproto.Repo {
	///The verifying conformer. A consumer that wants real verification injects
	///this at its composition root; a space-constrained one injects
	///`Atproto.Repo.ProofUnavailable` and never links this module.
	///
	///What this establishes that an internal-consistency check alone cannot:
	///the record is in the DID's repo. Checking a declaration against its own
	///`currentKey` is satisfied for free by an attacker minting a well-formed
	///declaration binding their key to a victim's DID. Provenance is the
	///missing half, and a JSON `getRecord` discards exactly that.
	public struct Verifier: ProofVerifying {
		//atproto repo commits are v3
		static let supportedCommitVersion: Int64 = 3

		public init() {}

		public func verifyRecordProof(
			car: Data,
			did: Atproto.DID,
			path: RecordPath,
			document: Atproto.DIDDocument
		) throws -> Proof {
			let signingKey = try RepoSigningKey(atprotoKeyIn: document, did: did)
			let archive = try CARv1(car)

			//the CAR's first root is the commit the proof is rooted at; every
			//block in the archive was checked against its own CID on the way in
			guard let commitCID = archive.roots.first else {
				throw ProofError.noCARRoots
			}
			let commitBytes = try archive.block(commitCID)
			let commit = try DAGCBORDecoder.decode(commitBytes)

			let rev = try checkCommit(commit, did: did, signingKey: signingKey)

			guard let mstRoot = commit["data"]?.linkValue else {
				throw ProofError.commitFieldMissing("data")
			}

			let recordCID = try MerkleSearchTree.find(
				key: path.mstKey,
				root: mstRoot,
				in: archive
			)
			guard recordCID.codec == .dagCBOR else {
				throw ProofError.unsupportedCodec(recordCID.codec.rawValue)
			}

			return Proof(
				did: did,
				path: path,
				cid: try recordCID.atprotoCID,
				block: try archive.block(recordCID),
				rev: rev
			)
		}

		///Returns the commit's `rev` once the signature over it holds.
		func checkCommit(
			_ commit: DAGCBORValue,
			did: Atproto.DID,
			signingKey: RepoSigningKey
		) throws -> String {
			guard case .map = commit else {
				throw ProofError.commitNotAnObject
			}

			guard let subject = commit["did"]?.stringValue else {
				throw ProofError.commitFieldMissing("did")
			}
			//without this the proof is real but about somebody else's repo
			guard subject == did.rawValue else {
				throw ProofError.commitDIDMismatch(
					expected: did.rawValue,
					found: subject
				)
			}

			guard let version = commit["version"]?.integerValue else {
				throw ProofError.commitFieldMissing("version")
			}
			guard version == Self.supportedCommitVersion else {
				throw ProofError.unsupportedCommitVersion(version)
			}

			guard let rev = commit["rev"]?.stringValue else {
				throw ProofError.commitFieldMissing("rev")
			}
			guard let signature = commit["sig"]?.bytesValue else {
				throw ProofError.missingSignature
			}

			//the signature covers the commit with `sig` removed, so the
			//preimage has to be rebuilt — which is the only reason this module
			//carries an encoder at all
			let preimage = DAGCBOREncoder.encode(commit.removing(key: "sig"))
			try signingKey.verify(signature: signature, over: preimage)

			return rev
		}
	}
}
