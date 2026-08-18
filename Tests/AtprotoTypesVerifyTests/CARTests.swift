//
//  CARTests.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import AtprotoTypesVerifyMocks
import Foundation
import Testing

@testable import AtprotoTypesVerify

@Suite("CAR v1")
struct CARTests {
	@Test("blocks round-trip through the framing")
	func roundTrip() throws {
		let first = try RepoFixture.block(.string("first"))
		let second = try RepoFixture.block(.integer(42))
		let archive = try CARv1(
			RepoFixture.car(root: first.cid, blocks: [first, second])
		)

		#expect(archive.roots == [first.cid])
		#expect(archive.blockCount == 2)
		#expect(try archive.block(first.cid) == first.bytes)
		#expect(try archive.decoded(second.cid) == .integer(42))
	}

	///The check the whole scheme depends on. A CAR is just a bag of bytes with
	///addresses attached, and the addresses are only meaningful because they
	///are recomputed here rather than believed.
	@Test("a block that does not hash to its stated CID is rejected on load")
	func rejectsMismatchedBlock() throws {
		let real = try RepoFixture.block(.string("honest"))
		let swapped = RepoFixture.Block(
			cid: real.cid,
			bytes: DAGCBOREncoder.encode(.string("tampered"))
		)

		#expect(throws: Atproto.Repo.ProofError.blockCIDMismatch(real.cid.string)) {
			try CARv1(RepoFixture.car(root: real.cid, blocks: [swapped]))
		}
	}

	@Test("an unsupported CAR version is rejected")
	func rejectsVersion() throws {
		let block = try RepoFixture.block(.string("x"))
		let header = DAGCBOREncoder.encode(
			.map([
				("roots", .array([.link(block.cid)])),
				("version", .integer(2)),
			])
		)
		var car = Data()
		car.append(contentsOf: ContentIdentifier.varint(UInt64(header.count)))
		car.append(header)

		#expect(throws: Atproto.Repo.ProofError.unsupportedCARVersion(2)) {
			try CARv1(car)
		}
	}

	@Test("a CAR with no roots is rejected")
	func rejectsNoRoots() throws {
		let header = DAGCBOREncoder.encode(
			.map([
				("roots", .array([])),
				("version", .integer(1)),
			])
		)
		var car = Data()
		car.append(contentsOf: ContentIdentifier.varint(UInt64(header.count)))
		car.append(header)

		#expect(throws: Atproto.Repo.ProofError.noCARRoots) {
			try CARv1(car)
		}
	}

	@Test("asking for a block the proof omits is an error, not an empty answer")
	func rejectsMissingBlock() throws {
		let present = try RepoFixture.block(.string("present"))
		let absent = try RepoFixture.block(.string("absent"))
		let archive = try CARv1(
			RepoFixture.car(root: present.cid, blocks: [present])
		)

		#expect(throws: Atproto.Repo.ProofError.missingBlock(absent.cid.string)) {
			try archive.block(absent.cid)
		}
	}

	@Test("a truncated block frame is rejected")
	func rejectsTruncation() throws {
		let block = try RepoFixture.block(.string("whole"))
		let car = RepoFixture.car(root: block.cid, blocks: [block])

		#expect(throws: Atproto.Repo.ProofError.truncated) {
			try CARv1(car.dropLast(3))
		}
	}
}
