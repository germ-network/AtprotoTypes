//
//  RepoProof.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 8/17/26.
//

import Foundation

///The seam, and only the seam. Everything that can actually check a proof —
///CAR framing, DAG-CBOR, the MST walk, curve arithmetic — lives in
///`AtprotoTypesVerify`, an additive product a space-constrained consumer can
///simply not link. This file has to stay cheap enough that linking it costs
///such a consumer nothing.
extension Atproto {
	public enum Repo {}
}

extension Atproto.Repo {
	///Where a record sits in a repo. The MST keys a record by
	///`collection/rkey`, so that string is the thing an inclusion proof is
	///actually about.
	public struct RecordPath: Sendable, Hashable {
		public let collection: Atproto.NSID
		public let rkey: String

		public init(collection: Atproto.NSID, rkey: String) {
			self.collection = collection
			self.rkey = rkey
		}

		public var mstKey: String {
			collection.rawValue + "/" + rkey
		}
	}

	///A record that is *in* a DID's repo, as distinct from one a server handed
	///us while claiming to speak for that DID. `verified(for:)`-style internal
	///consistency checks establish the latter and cannot establish the former:
	///an attacker mints a well-formed record binding their own key to a
	///victim's DID and passes it. What they cannot do is get it into the
	///victim's repo under a commit signed by the victim's signing key, which is
	///exactly what this value witnesses.
	public struct Proof: Sendable {
		public let did: Atproto.DID
		public let path: RecordPath
		///The record's own CID, recomputed from `block` rather than trusted.
		public let cid: Atproto.CID
		///The DAG-CBOR bytes the CID commits to.
		public let block: Data
		///The repo revision the commit carried, for ordering two proofs.
		public let rev: String

		public init(
			did: Atproto.DID,
			path: RecordPath,
			cid: Atproto.CID,
			block: Data,
			rev: String
		) {
			self.did = did
			self.path = path
			self.cid = cid
			self.block = block
			self.rev = rev
		}
	}

	public protocol ProofVerifying: Sendable {
		///Checks a CAR — a signed commit plus an inclusion proof: that the
		///commit is signed by `document`'s atproto signing key, that the MST
		///proves `path` from the signed commit's root, and that the record
		///block hashes to the CID the MST names.
		///
		///Deliberately pure and synchronous, and it takes no view on where the
		///bytes came from. That is the point: CAR is self-authenticating, so a
		///relay can withhold or replay but never forge, and the same check holds
		///for a monitor's `/records/{did}` and for the DID's own PDS alike.
		///Keeping the fetch out also makes this testable without a network and
		///makes it plain the verifier cannot go and ask anyone anything.
		func verifyRecordProof(
			car: Data,
			did: Atproto.DID,
			path: RecordPath,
			document: Atproto.DIDDocument
		) throws -> Proof
	}

	///What a space-constrained consumer injects instead of linking
	///`AtprotoTypesVerify`. It refuses rather than passing the record through
	///unverified: a caller asking for a proof must never receive a value that
	///merely looks like one.
	public struct ProofUnavailable: ProofVerifying {
		public init() {}

		public func verifyRecordProof(
			car: Data,
			did: Atproto.DID,
			path: RecordPath,
			document: Atproto.DIDDocument
		) throws -> Proof {
			throw Errors.verificationUnavailable
		}
	}

	public enum Errors: Error, Equatable, LocalizedError {
		case verificationUnavailable

		public var errorDescription: String? {
			switch self {
			case .verificationUnavailable:
				"Repo verification is not available in this build"
			}
		}
	}
}
