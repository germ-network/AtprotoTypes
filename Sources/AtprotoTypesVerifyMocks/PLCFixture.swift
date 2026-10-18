//
//  PLCFixture.swift
//  AtprotoTypesVerifyMocks
//
//  Created by Mark @ Germ on 10/18/26.
//

import AtprotoTypes
import AtprotoTypesVerify
import Crypto
import Foundation

///Builds `did:plc` operation logs rather than pinning captured bytes, for the
///same reason ``RepoFixture`` builds repos: a captured log tests that the
///verifier still accepts one capture, while a built one lets a test forge a
///single field — a `prev`, a signature, the genesis — and watch the verifier
///refuse for the reason it should rather than for whatever a blob happens to
///contain.
///
///Only touches `AtprotoTypesVerify`'s public and package API, and takes its
///signing keys through ``RepoFixtureSigningKey``, so a k256 case can be driven
///from the test target without this module depending on a signing library.
public enum PLCFixture {
	public struct Service: Sendable, Hashable {
		public let type: String
		public let endpoint: String

		public init(type: String, endpoint: String) {
			self.type = type
			self.endpoint = endpoint
		}
	}

	///A rotation key as an operation carries it: `did:key:z…`.
	public static func didKey(_ key: some RepoFixturePublicKey) -> String {
		"did:key:" + RepoFixture.multibase(key)
	}

	///A current-format `plc_operation`, unsigned.
	///
	///`verificationMethods` and `services` are pairs rather than dictionaries so
	///the caller fixes the key order — the rendered document's arrays follow it.
	public static func unsignedOperation(
		rotationKeys: [String],
		verificationMethods: [(key: String, value: String)],
		alsoKnownAs: [String],
		services: [(key: String, value: Service)],
		prev: Atproto.CID?
	) -> DAGCBORValue {
		.map([
			(key: "type", value: .string("plc_operation")),
			(key: "rotationKeys", value: .array(rotationKeys.map { .string($0) })),
			(
				key: "verificationMethods",
				value: .map(
					verificationMethods.map {
						(key: $0.key, value: DAGCBORValue.string($0.value))
					})
			),
			(key: "alsoKnownAs", value: .array(alsoKnownAs.map { .string($0) })),
			(
				key: "services",
				value: .map(
					services.map {
						(
							key: $0.key,
							value: DAGCBORValue.map([
								(
									key: "type",
									value: .string(
										$0.value.type)
								),
								(
									key: "endpoint",
									value: .string(
										$0.value.endpoint)
								),
							])
						)
					})
			),
			(key: "prev", value: prev.map { .string($0.string) } ?? .null),
		])
	}

	///A deprecated legacy `create` genesis, unsigned — the format whose bytes
	///the DID is derived from, which is not the format a regular operation
	///renders in.
	public static func unsignedLegacyCreate(
		signingKey: String,
		recoveryKey: String,
		handle: String,
		service: String
	) -> DAGCBORValue {
		.map([
			(key: "type", value: .string("create")),
			(key: "signingKey", value: .string(signingKey)),
			(key: "recoveryKey", value: .string(recoveryKey)),
			(key: "handle", value: .string(handle)),
			(key: "service", value: .string(service)),
			(key: "prev", value: .null),
		])
	}

	///An unsigned `plc_tombstone`, which carries only `type`, `prev` and `sig`.
	public static func unsignedTombstone(prev: Atproto.CID) -> DAGCBORValue {
		.map([
			(key: "type", value: .string("plc_tombstone")),
			(key: "prev", value: .string(prev.string)),
		])
	}

	///The one way a fixture call can fail: something that is not an operation
	///map. The builders in this type always produce one, so this is a caller
	///handing `signed` a value it built itself.
	public enum Error: Swift.Error, Equatable {
		case operationIsNotAMap
	}

	///Adds `sig` to an unsigned operation, or substitutes one — the seam a test
	///uses to forge a signature without touching anything else.
	public static func signed(
		_ unsigned: DAGCBORValue,
		with signer: some RepoFixtureSigningKey,
		sig: Data? = nil
	) throws -> DAGCBORValue {
		guard case .map(let fields) = unsigned else {
			throw Error.operationIsNotAMap
		}
		let signature =
			try sig
			?? signer.repoFixtureSignature(for: DAGCBOREncoder.encode(unsigned))
		return .map(
			fields + [(key: "sig", value: .string(Base64URL.encode(signature)))])
	}

	///The CID a source would carry for a signed operation.
	public static func cid(_ signed: DAGCBORValue) throws -> Atproto.CID {
		try ContentIdentifier.compute(
			codec: .dagCBOR, block: DAGCBOREncoder.encode(signed)
		).atprotoCID
	}

	///The log entry a source would serve for a signed operation.
	public static func entry(
		_ signed: DAGCBORValue,
		nullified: Bool = false
	) throws -> Atproto.PLC.LogEntry {
		Atproto.PLC.LogEntry(
			cid: try cid(signed),
			operationJSON: signed.jsonText(),
			nullified: nullified
		)
	}

	///The DID a signed genesis operation defines.
	public static func genesisDID(_ signedGenesis: DAGCBORValue) throws -> Atproto.DID {
		let digest = Data(SHA256.hash(data: DAGCBOREncoder.encode(signedGenesis)))
		let encoded = ContentIdentifier.base32Lower(digest)
		return Atproto.DID(method: .plc, identifier: String(encoded.prefix(24)))
	}
}
