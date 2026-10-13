//
//  PutRecordSwapEncodingTests.swift
//  AtprotoTypes
//

import AtprotoTypes
import Foundation
import Testing

struct PutRecordSwapEncodingTests {
	struct Thing: Atproto.Record {
		struct Collection: Atproto.RecordType {
			static var nsid: Atproto.NSID { .init(string: "example.thing") }
			init() {}
			init(from decoder: any Decoder) throws { self.init() }
			func encode(to encoder: any Encoder) throws {
				var container = encoder.singleValueContainer()
				try container.encode(Self.nsid.rawValue)
			}
		}
		typealias Key = Atproto.LiteralSelfRecordKey
		var nsid: Collection { .init() }
		var name = "x"
		private enum CodingKeys: String, CodingKey { case name }
	}

	typealias Schema = Lexicon.Com.Atproto.Repo.PutRecord<Thing>.Input.Schema
	static let cidString = "bafyreibmcnkzbxtciyydktbatjlpgh5hollpov4zvpwtaaq353vyzfbxwu"

	static func schema(
		swap: Atproto.RecordSwap?
	) throws -> Schema {
		.init(
			repo: try .init(string: "did:plc:abcdefghijklmnopqrstuvwx"),
			rkey: .init(),
			record: Thing(),
			swap: swap
		)
	}

	static func json(_ schema: Schema) throws -> [String: Any] {
		let data = try JSONEncoder().encode(schema)
		return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
	}

	@Test
	func absentEncodesExplicitNull() throws {
		let object = try Self.json(Self.schema(swap: .absent))
		#expect(object.keys.contains("swapRecord"))
		#expect(object["swapRecord"] is NSNull)
	}

	@Test
	func recordEncodesCIDString() throws {
		let cid = try Atproto.CID(string: Self.cidString)
		let object = try Self.json(Self.schema(swap: .record(cid)))
		#expect(object["swapRecord"] as? String == cid.string)
	}

	@Test
	func nilSwapOmitsKey() throws {
		let minimal: Set<String> = ["repo", "collection", "rkey", "record"]
		#expect(Set(try Self.json(Self.schema(swap: nil)).keys) == minimal)
		let legacy = Schema(
			repo: try .init(string: "did:plc:abcdefghijklmnopqrstuvwx"),
			rkey: .init(),
			record: Thing(),
			swapRecord: nil
		)
		#expect(Set(try Self.json(legacy).keys) == minimal)
	}

	@Test
	func legacyInitEncodesUnchanged() throws {
		let cid = try Atproto.CID(string: Self.cidString)
		let schema = Schema(
			repo: try .init(string: "did:plc:abcdefghijklmnopqrstuvwx"),
			rkey: .init(),
			record: Thing(),
			validate: true,
			swapCommit: cid,
			swapRecord: cid
		)
		let encoded = try JSONEncoder().encode(schema)
		let expected =
			#"{"repo":"did:plc:abcdefghijklmnopqrstuvwx","collection":"example.thing","rkey":"self","record":{"name":"x"},"validate":true,"swapCommit":"\#(Self.cidString)","swapRecord":"\#(Self.cidString)"}"#
		// structural on purpose: JSONEncoder key order is not deterministic without .sortedKeys
		let object = try JSONSerialization.jsonObject(with: encoded) as? NSDictionary
		let expectedObject =
			try JSONSerialization.jsonObject(with: Data(expected.utf8)) as? NSDictionary
		#expect(object == expectedObject)
	}

	@Test
	func decodeDistinguishesNullFromMissing() throws {
		let base =
			#""repo":"did:plc:abcdefghijklmnopqrstuvwx","collection":"example.thing","rkey":"self","record":{"name":"x"}"#
		let decoder = JSONDecoder()
		let null = try decoder.decode(
			Schema.self, from: Data("{\(base),\"swapRecord\":null}".utf8))
		#expect(null.swap == .absent)
		let missing = try decoder.decode(Schema.self, from: Data("{\(base)}".utf8))
		#expect(missing.swap == nil)
		let cid = try decoder.decode(
			Schema.self,
			from: Data("{\(base),\"swapRecord\":\"\(Self.cidString)\"}".utf8))
		#expect(cid.swap == .record(try Atproto.CID(string: Self.cidString)))
	}
}
