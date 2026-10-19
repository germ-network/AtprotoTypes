//
//  PLCLogVerifier.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 10/18/26.
//

import AtprotoTypes
import Crypto
import Foundation

extension Atproto.PLC {
	///The verifying conformer. A consumer that wants a served log checked
	///injects this at its composition root; a space-constrained one injects
	///`Atproto.PLC.LogUnavailable` and never links this module.
	///
	///What this establishes that reading a served document cannot: the document
	///follows from bytes the DID's own rotation keys signed, so a relay can
	///withhold or truncate a log but cannot forge one. The relay's word for a
	///document is a claim about the directory; a verified log is a claim the
	///device checked itself.
	public struct Verifier: LogVerifying {
		public init() {}

		public func verifyLog(
			did: Atproto.DID,
			entries: [Atproto.PLC.LogEntry]
		) throws -> Atproto.PLC.VerifiedDocument {
			guard did.method == .plc else {
				throw VerifyError.notAPlcDID(did)
			}
			guard !entries.isEmpty else {
				throw VerifyError.emptyLog
			}

			//Every entry's claimed CID is recomputed rather than believed: the
			//rest of the chain is checked against these CIDs, so a log that
			//supplied them would be free to re-point its own `prev` links.
			var operations: [Operation] = []
			operations.reserveCapacity(entries.count)
			for entry in entries {
				let operation = try Operation.parse(json: entry.operationJSON)
				let computed = try ContentIdentifier.compute(
					codec: .dagCBOR,
					block: DAGCBOREncoder.encode(operation.signed)
				).atprotoCID
				guard computed == entry.cid else {
					throw VerifyError.cidMismatch(
						claimed: entry.cid, computed: computed)
				}
				operations.append(operation)
			}

			let genesis = operations[0]
			guard !entries[0].nullified else {
				throw VerifyError.genesisIsNullified
			}
			//The first slot is the genesis, and a genesis points at nothing. A
			//first operation carrying a `prev` is an update wearing the first
			//slot — its own rule rather than the chain's first step, since there
			//is no previous live operation for it to disagree with.
			guard genesis.prev == nil else {
				throw VerifyError.genesisHasNonNilPrev
			}
			let derived = genesisDID(of: genesis.signed)
			guard derived == did else {
				throw VerifyError.genesisDoesNotHashToTheDID(
					expected: did, found: derived)
			}
			//A genesis is signed by its own rotation keys; every later operation
			//by the keys the operation before it established, which is what makes
			//a rotation take effect only for the operations after it.
			try verifySignature(of: genesis, under: genesis.rotationKeys)

			//Nullified operations are not part of the live chain, so the chain
			//runs through them rather than over them. Nothing re-derives which
			//operations are nullified — that is the directory's judgement of
			//recovery windows and key priority, taken on the same trust as the
			//log's completeness. That includes the tombstone rule below: a
			//nullified operation after a tombstone is not a live successor, so
			//it is skipped rather than refused.
			var lastLiveIndex = 0
			var tombstoned = false
			for index in 1..<entries.count {
				guard !entries[index].nullified else { continue }
				if tombstoned {
					throw VerifyError.operationAfterTombstone
				}
				let operation = operations[index]
				let expected = entries[lastLiveIndex].cid
				guard operation.prev == expected else {
					throw VerifyError.chainBroken(
						expected: expected, found: operation.prev)
				}
				try verifySignature(
					of: operation, under: operations[lastLiveIndex].rotationKeys
				)
				if operation.isTombstone {
					tombstoned = true
				}
				lastLiveIndex = index
			}

			let document =
				operations[lastLiveIndex].isTombstone
				? try DocumentRenderer.renderTombstone(did: did)
				: try DocumentRenderer.render(
					did: did, operation: operations[lastLiveIndex])

			return Atproto.PLC.VerifiedDocument(did: did, document: document)
		}

		///`did:plc:` + the first 24 characters of the base32 of the SHA-256 of
		///the signed genesis operation's DAG-CBOR bytes.
		///
		///The signed operation in its own format, before any legacy `create`
		///conversion: the identifier is the hash, so those DIDs are permanent
		///and a converted hash would name nothing.
		private func genesisDID(of signed: DAGCBORValue) -> Atproto.DID {
			let digest = Data(SHA256.hash(data: DAGCBOREncoder.encode(signed)))
			let encoded = ContentIdentifier.base32Lower(digest)
			return Atproto.DID(method: .plc, identifier: String(encoded.prefix(24)))
		}

		///Checks `operation`'s signature over its DAG-CBOR bytes without `sig`
		///against any of `keys`.
		private func verifySignature(
			of operation: Operation,
			under keys: [RepoSigningKey]
		) throws {
			let signature: Data
			do {
				signature = try Base64URL.decode(operation.sig)
			} catch {
				throw VerifyError.operationFieldMalformed("sig")
			}
			guard signature.count == 64 else {
				throw VerifyError.badSignatureLength(signature.count)
			}

			let message = DAGCBOREncoder.encode(operation.unsigned)
			for key in keys {
				do {
					try key.verify(signature: signature, over: message)
					return
				} catch Atproto.Repo.ProofError.nonCanonicalSignature {
					//A high-S twin is a second spelling of one signature, so
					//accepting it would let the operation's CID change without
					//invalidating the signature. That is a property of the
					//signature rather than of the key it was tried against, so it
					//is refused here rather than counted as a key that did not
					//match.
					throw VerifyError.nonCanonicalSignature
				} catch {
					continue
				}
			}
			throw VerifyError.noRotationKeyVerifiedTheSignature
		}
	}
}
