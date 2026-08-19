//
//  ProofError.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import Foundation

extension Atproto.Repo {
	///One enum for the whole verify path. These are all "the proof does not
	///hold", and a caller's only sound response to any of them is to refuse the
	///record — the distinctions exist to make a failure diagnosable, not to
	///invite a caller to treat some as recoverable.
	public enum ProofError: Error, Equatable, LocalizedError {
		//framing
		case truncated
		case varintOverflow
		case varintNotMinimal
		case trailingBytes

		//CID
		case unsupportedCIDVersion(UInt64)
		case unsupportedCodec(UInt64)
		case unsupportedHash(UInt64)
		case badDigestLength(Int)

		//DAG-CBOR
		case indefiniteLength
		case reservedAdditionalInfo(UInt8)
		case nonMinimalLength
		case unsupportedMajorType(UInt8)
		case unsupportedTag(UInt64)
		case unsupportedSimpleValue(UInt8)
		case nonStringMapKey
		case duplicateMapKey(String)
		case unorderedMapKeys(String, String)
		case badCIDLink
		case invalidUTF8
		case nestingTooDeep
		case integerOutOfRange

		//CAR
		case badCARHeader
		case unsupportedCARVersion(UInt64)
		case noCARRoots
		case blockCIDMismatch(String)
		case missingBlock(String)

		//commit
		case commitNotAnObject
		case commitFieldMissing(String)
		case commitDIDMismatch(expected: String, found: String)
		case unsupportedCommitVersion(Int64)
		case missingSignature

		//MST
		case mstNodeMalformed
		case mstPrefixOutOfRange
		case mstCycle
		case recordNotInTree

		//keys and signatures
		case noAtprotoSigningKey
		case signingKeyControllerMismatch
		case badMultibaseKey
		case unsupportedCurve(String)
		case badSignatureLength(Int)
		case nonCanonicalSignature
		case signatureDidNotVerify

		public var errorDescription: String? {
			switch self {
			case .truncated: "Proof ended mid-value"
			case .varintOverflow: "Varint too large"
			case .varintNotMinimal: "Varint not minimally encoded"
			case .trailingBytes: "Unexpected trailing bytes"
			case .unsupportedCIDVersion(let v): "Unsupported CID version \(v)"
			case .unsupportedCodec(let c):
				"Unsupported CID codec 0x\(String(c, radix: 16))"
			case .unsupportedHash(let h):
				"Unsupported multihash 0x\(String(h, radix: 16))"
			case .badDigestLength(let l): "Bad digest length \(l)"
			case .indefiniteLength: "Indefinite-length CBOR is not DAG-CBOR"
			case .reservedAdditionalInfo(let i):
				"Reserved CBOR additional info \(i)"
			case .nonMinimalLength: "CBOR length not minimally encoded"
			case .unsupportedMajorType(let m): "Unsupported CBOR major type \(m)"
			case .unsupportedTag(let t): "Unsupported CBOR tag \(t)"
			case .unsupportedSimpleValue(let v): "Unsupported CBOR simple value \(v)"
			case .nonStringMapKey: "DAG-CBOR map keys must be strings"
			case .duplicateMapKey(let k): "Duplicate map key \(k)"
			case .unorderedMapKeys(let a, let b):
				"Map keys out of order: \(a) before \(b)"
			case .badCIDLink: "Malformed CID link"
			case .invalidUTF8: "Invalid UTF-8 in text string"
			case .nestingTooDeep: "DAG-CBOR nesting too deep"
			case .integerOutOfRange: "Integer outside the representable range"
			case .badCARHeader: "Malformed CAR header"
			case .unsupportedCARVersion(let v): "Unsupported CAR version \(v)"
			case .noCARRoots: "CAR declares no roots"
			case .blockCIDMismatch(let c): "Block does not hash to its CID \(c)"
			case .missingBlock(let c): "Proof omits block \(c)"
			case .commitNotAnObject: "Commit is not a map"
			case .commitFieldMissing(let f): "Commit is missing \(f)"
			case .commitDIDMismatch(let e, let f):
				"Commit is for \(f), expected \(e)"
			case .unsupportedCommitVersion(let v): "Unsupported commit version \(v)"
			case .missingSignature: "Commit carries no signature"
			case .mstNodeMalformed: "Malformed MST node"
			case .mstPrefixOutOfRange: "MST entry prefix longer than previous key"
			case .mstCycle: "MST contains a cycle"
			case .recordNotInTree: "Record is not in the repo at that path"
			case .noAtprotoSigningKey: "DID document has no atproto signing key"
			case .signingKeyControllerMismatch:
				"Signing key is controlled by a different DID"
			case .badMultibaseKey: "Malformed multibase public key"
			case .unsupportedCurve(let c): "Unsupported curve \(c)"
			case .badSignatureLength(let l): "Bad signature length \(l)"
			case .nonCanonicalSignature: "Signature is not low-S"
			case .signatureDidNotVerify: "Commit signature did not verify"
			}
		}
	}
}
