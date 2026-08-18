//
//  RepoFixture.swift
//  AtprotoTypesVerifyMocks
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import AtprotoTypesVerify
import Crypto
import Foundation

///Builds real repos rather than pinning captured bytes: a signed commit over an
///MST over record blocks, framed as a CAR. Pinned blobs would test that the
///parser still parses one capture; building the structure lets a test say
///"forge this one field" and watch the proof fail for the reason it should.
///
///A real library target, not test-target-internal code, so any package that
///wants to build a synthetic repo for its own tests can depend on this rather
///than reimplementing it — the same shape as `AtprotoTypesMocks` alongside
///`AtprotoTypes`. It only touches `AtprotoTypesVerify`'s public API.
///A compressed EC public key this package knows how to publish in a DID
///document — just enough to build a multibase string, not to verify or sign.
///Lets `AtprotoTypesVerifyTests` mint a k256 fixture key from raw bytes (via
///P256K, a test-only dependency) without `AtprotoTypesVerifyMocks` itself
///needing to depend on it.
public protocol RepoFixturePublicKey {
	///multicodec, e.g. `0x1200` (p256) or `0xe7` (secp256k1).
	var repoFixtureMulticodec: UInt64 { get }
	///SEC1 compressed point, 33 bytes.
	var repoFixtureCompressedRepresentation: Data { get }
}

///A signing key `RepoFixture.commit` can use to produce a repo signature —
///P256's own type conforms below; a k256 conformance backed by P256K lives in
///`AtprotoTypesVerifyTests` only, since that library is a differential-test
///dependency, never a shipped one (`AtprotoTypesVerify` carries its own
///from-scratch, verify-only secp256k1 — no signing path, by design).
public protocol RepoFixtureSigningKey {
	associatedtype PublicKey: RepoFixturePublicKey
	var publicKey: PublicKey { get }
	///A 64-byte compact `r ‖ s` signature over `message`, already folded to
	///its low-S form — callers that want a malleable twin flip it after via
	///`RepoFixture.highS`, rather than every conformance having to know the
	///atproto policy itself.
	func repoFixtureSignature(for message: Data) throws -> Data
}

extension P256.Signing.PublicKey: RepoFixturePublicKey {
	public var repoFixtureMulticodec: UInt64 { 0x1200 }
	public var repoFixtureCompressedRepresentation: Data { compressedRepresentation }
}

extension P256.Signing.PrivateKey: RepoFixtureSigningKey {
	public func repoFixtureSignature(for message: Data) throws -> Data {
		RepoFixture.lowS(try signature(for: message).rawRepresentation, order: RepoSigningKey.p256Order)
	}
}

///A secp256k1 public key, wrapping only the bytes a multibase string needs.
///Dependency-free: `AtprotoTypesVerifyTests` decodes a P256K public key down
///to its compressed representation and wraps it here, so this package never
///needs to know P256K exists.
public struct Secp256k1PublicKey: RepoFixturePublicKey, Sendable {
	public let repoFixtureCompressedRepresentation: Data

	public init(compressedRepresentation: Data) {
		self.repoFixtureCompressedRepresentation = compressedRepresentation
	}

	public var repoFixtureMulticodec: UInt64 { 0xE7 }
}

public enum RepoFixture {
	public static let did = try! Atproto.DID(string: "did:plc:germverifytestsubject")
	public static let attacker = try! Atproto.DID(string: "did:plc:germverifytestforger")

	public struct Block {
		public let cid: ContentIdentifier
		public let bytes: Data

		public init(cid: ContentIdentifier, bytes: Data) {
			self.cid = cid
			self.bytes = bytes
		}
	}

	public static func block(_ value: DAGCBORValue) throws -> Block {
		let bytes = DAGCBOREncoder.encode(value)
		return Block(
			cid: try ContentIdentifier.compute(codec: .dagCBOR, block: bytes),
			bytes: bytes
		)
	}

	///A declaration-shaped record. The shape does not matter to the proof — the
	///proof is about where the bytes live — but a realistic one keeps the tests
	///honest about sizes and key ordering.
	public static func declaration(currentKey: Data) -> DAGCBORValue {
		.map([
			("$type", .string("com.germnetwork.declaration")),
			("currentKey", .bytes(currentKey)),
			("version", .string("1.0.0")),
		])
	}

	// MARK: - MST

	///One MST node holding `entries` in ascending key order with the shared
	///prefix of the preceding key elided, exactly as the format specifies.
	public static func node(
		entries: [(key: String, value: ContentIdentifier)],
		left: ContentIdentifier? = nil,
		subtrees: [String: ContentIdentifier] = [:]
	) -> DAGCBORValue {
		var encoded: [DAGCBORValue] = []
		var previous: [UInt8] = []

		for entry in entries {
			let key = Array(entry.key.utf8)
			var shared = 0
			while shared < min(previous.count, key.count),
				previous[shared] == key[shared]
			{
				shared += 1
			}

			encoded.append(
				.map([
					("k", .bytes(Data(key.dropFirst(shared)))),
					("p", .integer(Int64(shared))),
					("t", subtrees[entry.key].map { DAGCBORValue.link($0) } ?? .null),
					("v", .link(entry.value)),
				])
			)
			previous = key
		}

		return .map([
			("e", .array(encoded)),
			("l", left.map { DAGCBORValue.link($0) } ?? .null),
		])
	}

	// MARK: - Commit

	public static func commit(
		did: Atproto.DID,
		dataRoot: ContentIdentifier,
		rev: String = "3lbwqrstuvwxy",
		signedBy key: some RepoFixtureSigningKey
	) throws -> DAGCBORValue {
		let unsigned = DAGCBORValue.map([
			("data", .link(dataRoot)),
			("did", .string(did.rawValue)),
			("prev", .null),
			("rev", .string(rev)),
			("version", .integer(3)),
		])

		let signature = try key.repoFixtureSignature(for: DAGCBOREncoder.encode(unsigned))
		guard case .map(let fields) = unsigned else { fatalError("unreachable") }

		return .map(fields + [(key: "sig", value: .bytes(signature))])
	}

	// MARK: - CAR

	public static func car(root: ContentIdentifier, blocks: [Block]) -> Data {
		let header = DAGCBOREncoder.encode(
			.map([
				("roots", .array([.link(root)])),
				("version", .integer(1)),
			])
		)

		var out = Data()
		out.append(contentsOf: ContentIdentifier.varint(UInt64(header.count)))
		out.append(header)

		for block in blocks {
			var framed = block.cid.bytes
			framed.append(block.bytes)
			out.append(contentsOf: ContentIdentifier.varint(UInt64(framed.count)))
			out.append(framed)
		}
		return out
	}

	// MARK: - Identity

	///Built by decoding JSON because `VerificationMethod`'s initialiser is
	///package-scoped to AtprotoTypes. No loss — this is the shape a document
	///actually arrives in, so the fixture exercises the real decode.
	public static func document(
		did: Atproto.DID,
		key: some RepoFixturePublicKey,
		fragment: String = "#atproto",
		controller: String? = nil
	) throws -> Atproto.DIDDocument {
		try document(
			did: did,
			methods: [
				(
					id: did.rawValue + fragment,
					controller: controller ?? did.rawValue,
					multibase: multibase(key)
				)
			]
		)
	}

	public static func document(
		did: Atproto.DID,
		methods: [(id: String, controller: String, multibase: String)]
	) throws -> Atproto.DIDDocument {
		let encoded = methods.map {
			"""
			{"id":"\($0.id)","type":"Multikey",\
			"controller":"\($0.controller)",\
			"publicKeyMultibase":"\($0.multibase)"}
			"""
		}
		.joined(separator: ",")

		let json = """
			{"@context":[],"id":"\(did.rawValue)","alsoKnownAs":[],\
			"verificationMethod":[\(encoded)],"service":[]}
			"""
		return try JSONDecoder().decode(
			Atproto.DIDDocument.self,
			from: Data(json.utf8)
		)
	}

	///The multicodec prefix over the compressed point, multibase base58btc —
	///the form a DID document publishes, for whichever curve `key` names.
	public static func multibase(_ key: some RepoFixturePublicKey) -> String {
		var payload = Data(ContentIdentifier.varint(key.repoFixtureMulticodec))
		payload.append(key.repoFixtureCompressedRepresentation)
		return "z" + BaseXEncoding.base58BTC(payload)
	}

	// MARK: - Low-S

	///swift-crypto does not normalise `s`, and atproto requires the low
	///variant, so fixtures fold it here rather than emitting signatures the
	///verifier is right to reject.
	///
	///No default `order` parameter: the default would have to name
	///`RepoSigningKey.p256Order`, a `package`-scoped constant, from this
	///public API's default-argument expression — which the compiler
	///evaluates at each call site, outside the package. This overload is the
	///substitute.
	public static func lowS(_ signature: Data) -> Data {
		lowS(signature, order: RepoSigningKey.p256Order)
	}

	public static func lowS(_ signature: Data, order: [UInt8]) -> Data {
		let r = Array(signature.prefix(32))
		let s = Array(signature.suffix(32))
		guard !RepoSigningKey.isLowS(s, order: order) else {
			return signature
		}
		return Data(r + subtract(order, s))
	}

	///Flips a signature to its high-S twin, for the malleability test.
	public static func highS(_ signature: Data) -> Data {
		highS(signature, order: RepoSigningKey.p256Order)
	}

	public static func highS(_ signature: Data, order: [UInt8]) -> Data {
		let r = Array(signature.prefix(32))
		let s = Array(signature.suffix(32))
		guard RepoSigningKey.isLowS(s, order: order) else {
			return signature
		}
		return Data(r + subtract(order, s))
	}

	public static func subtract(_ lhs: [UInt8], _ rhs: [UInt8]) -> [UInt8] {
		var out = [UInt8](repeating: 0, count: lhs.count)
		var borrow = 0
		for index in stride(from: lhs.count - 1, through: 0, by: -1) {
			let difference = Int(lhs[index]) - Int(rhs[index]) - borrow
			if difference < 0 {
				out[index] = UInt8(difference + 256)
				borrow = 1
			} else {
				out[index] = UInt8(difference)
				borrow = 0
			}
		}
		return out
	}
}

///base58btc encode, for building the multibase key strings the fixtures
///publish. `BaseX` decodes in `AtprotoTypesVerify`; encoding here keeps the
///fixture from depending on the same code path it is meant to feed.
public enum BaseXEncoding {
	static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

	public static func base58BTC(_ data: Data) -> String {
		var digits: [Int] = []
		for byte in data {
			var carry = Int(byte)
			for index in digits.indices {
				carry += digits[index] << 8
				digits[index] = carry % 58
				carry /= 58
			}
			while carry > 0 {
				digits.append(carry % 58)
				carry /= 58
			}
		}

		let leadingZeros = data.prefix { $0 == 0 }.count
		return String(
			repeating: "1", count: leadingZeros
		) + String(digits.reversed().map { alphabet[$0] })
	}
}
