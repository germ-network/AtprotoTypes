//
//  RepoWriteOutputDecodingTests.swift
//  AtprotoTypes
//

import AtprotoTypes
import Foundation
import GermConvenience
import GermConvenienceHTTP
import HTTPTypes
import Testing

//The lexicons require only `uri` and `cid` on putRecord/createRecord output and
//nothing on deleteRecord output. A PDS omits `commit` when the write is a no-op
//(an identical record, or deleting a record that doesn't exist), and
//`validationStatus` is an open knownValues string.
struct RepoWriteOutputDecodingTests {
	typealias PutRecord = Lexicon.Com.Atproto.Repo.PutRecord<
		PutRecordSwapEncodingTests.Thing
	>
	typealias DeleteRecord = Lexicon.Com.Atproto.Repo.DeleteRecord<
		PutRecordSwapEncodingTests.Thing
	>

	static let uri = "at://did:plc:abcdefghijklmnopqrstuvwx/example.thing/self"
	static let cid = PutRecordSwapEncodingTests.cidString
	static let rev = "3lbwqrstuvwxy"

	static func ok(_ json: String) -> HTTPDataResponse {
		.init(data: Data(json.utf8), response: .init(status: .ok))
	}

	static func parsed<P: Atproto.XRPC.ResponseParsing>(
		_: P.Type, _ json: String
	) throws -> P.Output {
		let parsed = try P.parse(fullResponse: ok(json))
		guard case .ok(let output) = parsed else {
			Issue.record("expected .ok, got \(parsed)")
			throw ParseFailed()
		}
		return output
	}
	struct ParseFailed: Error {}

	@Test func putRecordNoOpWithoutCommitParses() throws {
		let output = try Self.parsed(
			PutRecord.self,
			#"{"uri":"\#(Self.uri)","cid":"\#(Self.cid)","validationStatus":"valid"}"#)
		#expect(output.uri == Self.uri)
		#expect(output.cid == Self.cid)
		#expect(output.commit == nil)
		#expect(output.validationStatus == .valid)
	}

	@Test func putRecordWithoutValidationStatusParses() throws {
		let output = try Self.parsed(
			PutRecord.self,
			#"{"uri":"\#(Self.uri)","cid":"\#(Self.cid)","commit":{"cid":"\#(Self.cid)","rev":"\#(Self.rev)"}}"#
		)
		#expect(output.cid == Self.cid)
		#expect(output.validationStatus == nil)
	}

	@Test func putRecordUnrecognizedValidationStatusParses() throws {
		let output = try Self.parsed(
			PutRecord.self,
			#"{"uri":"\#(Self.uri)","cid":"\#(Self.cid)","commit":{"cid":"\#(Self.cid)","rev":"\#(Self.rev)"},"validationStatus":"deferred"}"#
		)
		#expect(output.validationStatus?.rawValue == "deferred")
	}

	@Test func putRecordWriteKeepsCommit() throws {
		let output = try Self.parsed(
			PutRecord.self,
			#"{"uri":"\#(Self.uri)","cid":"\#(Self.cid)","commit":{"cid":"\#(Self.cid)","rev":"\#(Self.rev)"},"validationStatus":"valid"}"#
		)
		#expect(output.commit?.rev.rawValue == Self.rev)
		#expect(output.validationStatus == .valid)
	}

	@Test func deleteRecordNoOpEmptyBodyParses() throws {
		let output = try Self.parsed(DeleteRecord.self, "{}")
		#expect(output.commit == nil)
	}

	@Test func validationStatusEncodesAsBareString() throws {
		let data = try JSONEncoder().encode(
			Lexicon.Com.Atproto.Repo.PutRecordOutput.ValidationStatus.valid)
		#expect(String(decoding: data, as: UTF8.self) == #""valid""#)
	}

	@Test func absentCommitIsOmittedWhenEncoding() throws {
		let output = Lexicon.Com.Atproto.Repo.PutRecordOutput(
			uri: Self.uri, cid: Self.cid, commit: nil, validationStatus: nil)
		let json = String(decoding: try JSONEncoder().encode(output), as: UTF8.self)
		#expect(!json.contains("commit"))
		#expect(!json.contains("validationStatus"))
	}
}
