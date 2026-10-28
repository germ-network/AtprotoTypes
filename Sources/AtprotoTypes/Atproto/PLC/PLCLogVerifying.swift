//
//  PLCLogVerifying.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 10/18/26.
//

import Foundation

///The `did:plc` seam, and only the seam — the same bargain as `Atproto.Repo`.
///A served document is not evidence, so a device that reads a signed operation
///log has to check it itself; the checking is DAG-CBOR, CID recomputation and
///curve arithmetic, all of which live in `AtprotoTypesVerify`. This file has to
///stay cheap enough that a space-constrained target can link it and still not
///link that.
extension Atproto {
	public enum PLC {}
}

extension Atproto.PLC {
	///One entry of a served `did:plc` audit log.
	///
	///The operation is kept as the JSON text the source sent rather than as a
	///decoded value, because re-encoding it is the verifier's job: both the CID
	///and the signature cover DAG-CBOR bytes, and producing those bytes from a
	///JSON document is exactly the part a relay must not be able to influence.
	public struct LogEntry: Sendable, Hashable {
		///The CID the source claims for this operation.
		public let cid: Atproto.CID

		///The operation as JSON text, `sig` included.
		public let operationJSON: String

		///Whether the directory considers this operation nullified. No signature
		///covers this — it is the directory's judgement of recovery windows and
		///key priority, and a verifier takes it on the same trust it takes the
		///log's completeness.
		public let nullified: Bool

		///From the wire: a CID string, parsed and then required to be in
		///canonical form.
		///
		///`Atproto.CID` normalizes — its base32 decoder takes either case and
		///tolerates padding — so two spellings of one CID parse to one value and
		///the parsed type alone could not tell a canonical claim from a merely
		///equivalent one. The claim is supposed to *be* the CID, not something
		///that decodes to it, so the spelling is checked here while it is still
		///in hand rather than normalized away.
		public init(cid claimed: String, operationJSON: String, nullified: Bool) throws {
			let parsed = try Atproto.CID(string: claimed)
			guard parsed.rawValue == claimed else {
				throw Errors.nonCanonicalCID(claimed)
			}
			self.init(cid: parsed, operationJSON: operationJSON, nullified: nullified)
		}

		///From a CID already in hand — a fixture's, or one the caller parsed
		///itself. There is no claim string to check, so there is nothing to
		///normalize away.
		public init(cid: Atproto.CID, operationJSON: String, nullified: Bool) {
			self.cid = cid
			self.operationJSON = operationJSON
			self.nullified = nullified
		}
	}

	///A DID document rebuilt from a signed `did:plc` operation log.
	///
	///The type is how the two standings are told apart, and it is the strongest
	///separation the language offers short of an unforgeable token: a
	///``LogVerifying`` implementation is what mints one, nothing converts a
	///``Hint`` into one, and a caller that mints one itself is lying to itself
	///rather than being misled by this module. The initializer is public for
	///the same reason `Atproto.Repo.Proof`'s is — a consumer's test double has
	///to be able to return one — which is exactly what makes the guarantee a
	///convention rather than a proof.
	public struct VerifiedDocument: Sendable, Equatable {
		public let did: Atproto.DID
		public let document: Atproto.DIDDocument

		public init(did: Atproto.DID, document: Atproto.DIDDocument) {
			self.did = did
			self.document = document
		}
	}

	///A document a relay served for a `did:web` DID: a hint, not evidence.
	///
	///Deliberately a different type from ``VerifiedDocument`` and not
	///convertible to it. A `did:web` document has no log behind it to check, so
	///the only honest thing to say about it is that someone asserted it; the
	///compiler is what keeps that from being mistaken for a verification.
	public struct Hint: Sendable, Equatable {
		public let did: Atproto.DID
		public let document: Atproto.DIDDocument

		public init(did: Atproto.DID, document: Atproto.DIDDocument) {
			self.did = did
			self.document = document
		}
	}

	public protocol LogVerifying: Sendable {
		///Verifies a `did:plc` audit log end to end and renders the document it
		///implies: the genesis operation hashes to `did` (in the legacy `create`
		///format if that is the format it was signed in), every entry's CID is
		///the SHA-256 CID of its DAG-CBOR bytes, the `prev` chain over the live
		///operations is unbroken, every signature holds under a rotation key the
		///log itself established, and a `plc_tombstone` ends it.
		///
		///Throws on anything that does not hold. There is no partial success and
		///no "unverified" return: a log that is merely truncated is still a log
		///that verified, and a log that is forged must produce no document at
		///all.
		func verifyLog(did: Atproto.DID, entries: [Atproto.PLC.LogEntry]) throws
			-> Atproto.PLC.VerifiedDocument
	}

	///What a space-constrained consumer injects instead of linking
	///`AtprotoTypesVerify`. It refuses rather than returning anything: a caller
	///that asked for a verified document must never receive one that was not.
	public struct LogUnavailable: LogVerifying {
		public init() {}

		public func verifyLog(did: Atproto.DID, entries: [Atproto.PLC.LogEntry]) throws
			-> Atproto.PLC.VerifiedDocument
		{
			throw Errors.verificationUnavailable
		}
	}

	public enum Errors: Error, Equatable, LocalizedError {
		case verificationUnavailable

		///A log entry's claimed CID is not in canonical base32 form. See
		///``LogEntry/init(cid:operationJSON:nullified:)`` for why the spelling
		///is checked rather than normalized.
		case nonCanonicalCID(String)

		public var errorDescription: String? {
			switch self {
			case .verificationUnavailable:
				"did:plc log verification is not available in this build"
			case .nonCanonicalCID(let cid):
				"\(cid) is not a canonical CID"
			}
		}
	}
}
