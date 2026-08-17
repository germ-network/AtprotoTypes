//
//  ContentIdentifierTests.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import Foundation
import Testing

@testable import AtprotoTypesVerify

@Suite("CID")
struct ContentIdentifierTests {
	///Anchored on the SHA-256 of the empty string, which is a constant anyone
	///can check, rather than on a base32 string copied from our own output.
	@Test("a raw CID over empty input has the known digest and binary prefix")
	func emptyDigest() throws {
		let cid = try ContentIdentifier.compute(codec: .raw, block: Data())

		#expect(
			Data(cid.digest).hexString
				== "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
		)
		//CIDv1, raw codec, sha2-256, 32 bytes
		#expect(Array(cid.bytes.prefix(4)) == [0x01, 0x55, 0x12, 0x20])
		#expect(cid.bytes.count == 36)
	}

	@Test("the binary form round-trips")
	func binaryRoundTrip() throws {
		let cid = try ContentIdentifier.compute(
			codec: .dagCBOR,
			block: Data("some block".utf8)
		)
		#expect(try ContentIdentifier(bytes: cid.bytes) == cid)
	}

	///The bridge back to AtprotoTypes' opaque CID has to agree with what that
	///type would have parsed, or a proven CID and a fetched one would not
	///compare equal.
	@Test("the string form matches what Atproto.CID parses")
	func atprotoBridge() throws {
		let cid = try ContentIdentifier.compute(
			codec: .dagCBOR,
			block: Data("some block".utf8)
		)
		#expect(cid.string.hasPrefix("bafyrei"))
		#expect(try cid.atprotoCID.string == cid.string)
		#expect(try Atproto.CID(string: cid.string).string == cid.string)
	}

	@Test("matches() recomputes rather than trusting the link")
	func matchesRecomputes() throws {
		let block = Data("payload".utf8)
		let cid = try ContentIdentifier.compute(codec: .dagCBOR, block: block)

		#expect(cid.matches(block: block))
		#expect(!cid.matches(block: Data("payloae".utf8)))
	}

	@Test("CIDv0 is rejected rather than quietly reinterpreted")
	func rejectsV0() {
		//a bare sha2-256 multihash, which is what a v0 CID is
		var v0 = Data([0x12, 0x20])
		v0.append(Data(repeating: 0xAB, count: 32))

		#expect(throws: Atproto.Repo.ProofError.unsupportedCIDVersion(0x12)) {
			try ContentIdentifier(bytes: v0)
		}
	}

	@Test("an unsupported multihash is rejected")
	func rejectsOtherHash() {
		//CIDv1, dag-cbor, blake2b-256 (0xb220)
		var cid = Data([0x01, 0x71, 0xA0, 0xE4, 0x02])
		cid.append(Data(repeating: 0x11, count: 32))

		#expect(throws: (any Error).self) {
			try ContentIdentifier(bytes: cid)
		}
	}

	@Test("trailing bytes after a CID are rejected")
	func rejectsTrailing() throws {
		let cid = try ContentIdentifier.compute(codec: .dagCBOR, block: Data())
		var padded = cid.bytes
		padded.append(0x00)

		#expect(throws: Atproto.Repo.ProofError.trailingBytes) {
			try ContentIdentifier(bytes: padded)
		}
	}

	@Test(
		"non-minimal varints are rejected",
		arguments: [
			//version 1 written as a two-byte varint
			"8100711220",
			//codec dag-cbor written as a two-byte varint
			"01f1001220",
		]
	)
	func rejectsNonMinimalVarint(prefix: String) {
		var bytes = Data(hex: prefix)
		bytes.append(Data(repeating: 0x00, count: 32))

		#expect(throws: (any Error).self) {
			try ContentIdentifier(bytes: bytes)
		}
	}
}

extension Data {
	var hexString: String {
		map { String(format: "%02x", $0) }.joined()
	}
}
