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
		signedBy key: P256.Signing.PrivateKey
	) throws -> DAGCBORValue {
		let unsigned = DAGCBORValue.map([
			("data", .link(dataRoot)),
			("did", .string(did.rawValue)),
			("prev", .null),
			("rev", .string(rev)),
			("version", .integer(3)),
		])

		let signature = try key.signature(for: DAGCBOREncoder.encode(unsigned))
		guard case .map(let fields) = unsigned else { fatalError("unreachable") }

		return .map(
			fields + [(key: "sig", value: .bytes(lowS(signature.rawRepresentation)))]
		)
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
		key: P256.Signing.PublicKey,
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

	///multicodec p256-pub (0x1200) over the compressed point, multibase
	///base58btc — the form a DID document publishes.
	public static func multibase(_ key: P256.Signing.PublicKey) -> String {
		var payload = Data([0x80, 0x24])
		payload.append(key.compressedRepresentation)
		return "z" + BaseXEncoding.base58BTC(payload)
	}

	// MARK: - Low-S

	///swift-crypto does not normalise `s`, and atproto requires the low
	///variant, so fixtures fold it here rather than emitting signatures the
	///verifier is right to reject.
	public static func lowS(_ signature: Data) -> Data {
		let r = Array(signature.prefix(32))
		let s = Array(signature.suffix(32))
		guard !RepoSigningKey.isLowS(s, order: RepoSigningKey.p256Order) else {
			return signature
		}
		return Data(r + subtract(RepoSigningKey.p256Order, s))
	}

	///Flips a signature to its high-S twin, for the malleability test.
	public static func highS(_ signature: Data) -> Data {
		let r = Array(signature.prefix(32))
		let s = Array(signature.suffix(32))
		guard RepoSigningKey.isLowS(s, order: RepoSigningKey.p256Order) else {
			return signature
		}
		return Data(r + subtract(RepoSigningKey.p256Order, s))
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
