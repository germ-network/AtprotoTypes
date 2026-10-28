//
//  PLCVerifyError.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 10/18/26.
//

import AtprotoTypes
import Foundation

extension Atproto.PLC {
	///One enum for the whole `did:plc` verify path, for the same reason
	///`Atproto.Repo.ProofError` is one: these are all "the log does not hold",
	///and a caller's only sound response to any of them is to refuse the
	///document. The distinctions exist to make a failure diagnosable, not to
	///invite a caller to treat some as recoverable.
	public enum VerifyError: Error, Equatable, LocalizedError {
		///The DID is not a `did:plc` — a `did:web` document has no log to check.
		case notAPlcDID(Atproto.DID)

		case emptyLog
		case operationNotAMap
		case malformedOperation(String)
		case unsupportedOperationType(String)
		case operationFieldMissing(String)
		case operationFieldMalformed(String)

		///The first entry's own bytes do not hash to the DID's identifier.
		case genesisDoesNotHashToTheDID(expected: Atproto.DID, found: Atproto.DID)
		case genesisIsNullified
		case genesisHasNonNilPrev

		///An entry's claimed CID is not the CID of the operation it carries. The
		///log is taken as a list of claims about what its operations hash to,
		///and this is the check that makes those claims mean anything.
		case cidMismatch(claimed: Atproto.CID, computed: Atproto.CID)

		///A live operation's `prev` is not the CID of the live operation before
		///it.
		case chainBroken(expected: Atproto.CID, found: Atproto.CID?)

		case operationAfterTombstone

		///The signature is not the 64-byte compact `r ‖ s` the method specifies.
		case badSignatureLength(Int)

		///The signature is not in low-S form. A property of the signature alone,
		///not of the key it is checked against, which is why it is a rejection
		///rather than a "this key did not match": a high-S twin is a second
		///spelling of one signature, and accepting it would let the operation's
		///CID change without invalidating its signature.
		case nonCanonicalSignature

		///A rotation key is not a `did:key` this package can read.
		case badRotationKey(String)

		///The signature is well-formed and no rotation key the log established
		///verifies it — the trust violation the method specification says the
		///directory should never have accepted.
		case noRotationKeyVerifiedTheSignature

		public var errorDescription: String? {
			switch self {
			case .notAPlcDID(let did):
				"\(did.rawValue) is not a did:plc"
			case .emptyLog: "The operation log is empty"
			case .operationNotAMap: "An operation is not an object"
			case .malformedOperation(let why): "Malformed operation: \(why)"
			case .unsupportedOperationType(let type):
				"Unsupported operation type \(type)"
			case .operationFieldMissing(let field): "Operation is missing \(field)"
			case .operationFieldMalformed(let field):
				"Operation field \(field) is malformed"
			case .genesisDoesNotHashToTheDID(let expected, let found):
				"Genesis hashes to \(found.rawValue), not \(expected.rawValue)"
			case .genesisIsNullified: "The genesis operation is nullified"
			case .genesisHasNonNilPrev: "The genesis operation carries a prev"
			case .cidMismatch(let claimed, let computed):
				"Entry claims \(claimed.rawValue), its operation hashes to \(computed.rawValue)"
			case .chainBroken(let expected, let found):
				"prev is \(found?.rawValue ?? "null"), expected \(expected.rawValue)"
			case .operationAfterTombstone:
				"A live operation follows a plc_tombstone"
			case .badSignatureLength(let length):
				"Signature is \(length) bytes, expected 64"
			case .nonCanonicalSignature: "Signature is not low-S"
			case .badRotationKey(let key): "Malformed rotation key \(key)"
			case .noRotationKeyVerifiedTheSignature:
				"No rotation key verifies the operation's signature"
			}
		}
	}
}
