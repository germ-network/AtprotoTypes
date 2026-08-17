//
//  DAGCBORTests.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import Foundation
import Testing

@testable import AtprotoTypesVerify

@Suite("DAG-CBOR")
struct DAGCBORTests {
	///RFC 8949 Appendix A. Pinned against the spec's own table rather than
	///against our encoder's output, so the two can't drift together.
	@Test(
		"the RFC 8949 example encodings round-trip",
		arguments: [
			(DAGCBORValue.integer(0), "00"),
			(.integer(1), "01"),
			(.integer(10), "0a"),
			(.integer(23), "17"),
			(.integer(24), "1818"),
			(.integer(100), "1864"),
			(.integer(1000), "1903e8"),
			(.integer(1_000_000), "1a000f4240"),
			(.integer(-1), "20"),
			(.integer(-10), "29"),
			(.integer(-100), "3863"),
			(.integer(-1000), "3903e7"),
			(.bool(false), "f4"),
			(.bool(true), "f5"),
			(.null, "f6"),
			(.string(""), "60"),
			(.string("a"), "6161"),
			(.string("IETF"), "6449455446"),
			(.array([]), "80"),
			(.array([.integer(1), .integer(2), .integer(3)]), "83010203"),
			(.map([]), "a0"),
		]
	)
	func rfcVectors(value: DAGCBORValue, hex: String) throws {
		let bytes = Data(hex: hex)
		#expect(DAGCBOREncoder.encode(value) == bytes)
		#expect(try DAGCBORDecoder.decode(bytes) == value)
	}

	///The property the commit signature rests on: rebuilding the preimage from
	///a decoded value has to reproduce the original bytes exactly, or the
	///digest we verify is not the digest that was signed.
	@Test("decode then encode reproduces the original bytes")
	func roundTrip() throws {
		let value = DAGCBORValue.map([
			("did", .string("did:plc:example")),
			("rev", .string("3lbw")),
			("data", .link(try ContentIdentifier.compute(codec: .dagCBOR, block: Data()))),
			("prev", .null),
			("nested", .array([.integer(-1), .bytes(Data([0, 1, 2])), .bool(true)])),
			("version", .integer(3)),
		])

		let encoded = DAGCBOREncoder.encode(value)
		#expect(DAGCBOREncoder.encode(try DAGCBORDecoder.decode(encoded)) == encoded)
	}

	@Test("maps encode in length-first canonical order regardless of input order")
	func canonicalOrdering() throws {
		//keys deliberately supplied out of order; "b" must precede "aa"
		let value = DAGCBORValue.map([
			("version", .integer(1)),
			("aa", .integer(2)),
			("b", .integer(3)),
		])

		let decoded = try DAGCBORDecoder.decode(DAGCBOREncoder.encode(value))
		guard case .map(let entries) = decoded else {
			Issue.record("expected a map")
			return
		}
		#expect(entries.map(\.key) == ["b", "aa", "version"])
	}

	@Test("a CID link survives the round trip")
	func linkRoundTrip() throws {
		let cid = try ContentIdentifier.compute(
			codec: .dagCBOR,
			block: Data("hello".utf8)
		)
		let encoded = DAGCBOREncoder.encode(.link(cid))
		//tag 42, then a byte string opening with the identity multibase prefix
		#expect(encoded.first == 0xD8)
		#expect(encoded[1] == 42)
		#expect(try DAGCBORDecoder.decode(encoded) == .link(cid))
	}

	// MARK: - Strictness

	@Test(
		"non-DAG-CBOR encodings are rejected",
		arguments: [
			//indefinite-length array, byte string, text string, map
			("9f01ff", "indefinite array"),
			("5f42010243030405ff", "indefinite bytes"),
			("7f61616161ff", "indefinite text"),
			("bf616101616202ff", "indefinite map"),
			//non-minimal integer: 1 written in a two-byte argument
			("1801", "non-minimal one-byte argument"),
			("190001", "non-minimal two-byte argument"),
			//reserved additional info
			("1c", "reserved additional info 28"),
			//half and single precision floats
			("f93c00", "float16"),
			("fa47c35000", "float32"),
			//an unsupported tag
			("c10a", "tag 1"),
		]
	)
	func rejectsNonCanonical(hex: String, label: String) {
		#expect(throws: (any Error).self, "\(label) should not decode") {
			try DAGCBORDecoder.decode(Data(hex: hex))
		}
	}

	@Test("integer map keys are rejected")
	func rejectsIntegerKeys() {
		//{1: 2}
		#expect(throws: Atproto.Repo.ProofError.nonStringMapKey) {
			try DAGCBORDecoder.decode(Data(hex: "a10102"))
		}
	}

	@Test("duplicate map keys are rejected")
	func rejectsDuplicateKeys() {
		//{"a": 1, "a": 2}
		#expect(throws: Atproto.Repo.ProofError.duplicateMapKey("a")) {
			try DAGCBORDecoder.decode(Data(hex: "a2616101616102"))
		}
	}

	@Test("out-of-order map keys are rejected")
	func rejectsUnorderedKeys() {
		//{"b": 1, "a": 2} — canonical order puts "a" first
		#expect(throws: Atproto.Repo.ProofError.unorderedMapKeys("b", "a")) {
			try DAGCBORDecoder.decode(Data(hex: "a2616201616102"))
		}
		//{"aa": 1, "b": 2} — length-first, so the one-byte key sorts first
		#expect(throws: Atproto.Repo.ProofError.unorderedMapKeys("aa", "b")) {
			try DAGCBORDecoder.decode(Data(hex: "a262616101616202"))
		}
	}

	@Test("trailing bytes after a complete value are rejected")
	func rejectsTrailingBytes() {
		#expect(throws: Atproto.Repo.ProofError.trailingBytes) {
			try DAGCBORDecoder.decode(Data(hex: "0101"))
		}
	}

	@Test("a truncated value is rejected rather than silently short")
	func rejectsTruncation() {
		//declares a four-byte string, supplies two
		#expect(throws: Atproto.Repo.ProofError.truncated) {
			try DAGCBORDecoder.decode(Data(hex: "646162"))
		}
	}

	@Test("a tag 42 payload without the identity multibase prefix is rejected")
	func rejectsBadLink() {
		//tag 42 over a byte string that starts with 0x01 rather than 0x00
		#expect(throws: Atproto.Repo.ProofError.badCIDLink) {
			try DAGCBORDecoder.decode(Data(hex: "d82a4401550120"))
		}
	}

	@Test("invalid UTF-8 in a text string is rejected")
	func rejectsInvalidUTF8() {
		#expect(throws: Atproto.Repo.ProofError.invalidUTF8) {
			try DAGCBORDecoder.decode(Data(hex: "62c328"))
		}
	}
}

extension Data {
	init(hex: String) {
		var bytes: [UInt8] = []
		var index = hex.startIndex
		while index < hex.endIndex,
			let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex)
		{
			bytes.append(UInt8(hex[index..<next], radix: 16) ?? 0)
			index = next
		}
		self.init(bytes)
	}
}
