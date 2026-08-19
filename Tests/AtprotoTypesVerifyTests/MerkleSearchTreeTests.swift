//
//  MerkleSearchTreeTests.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import AtprotoTypesVerifyMocks
import Foundation
import Testing

@testable import AtprotoTypesVerify

@Suite("MST")
struct MerkleSearchTreeTests {
	static let collection = "app.bsky.feed.post"

	///Root holds `b`, with `a` in the left subtree and `c` hanging off `b` —
	///so a lookup has to be able to stop at the root, descend left, and descend
	///right.
	struct Tree {
		let archive: CARv1
		let root: ContentIdentifier
		let values: [String: ContentIdentifier]

		init() throws {
			var blocks: [RepoFixture.Block] = []

			func leaf(_ name: String) throws -> ContentIdentifier {
				let block = try RepoFixture.block(.string("record-" + name))
				blocks.append(block)
				return block.cid
			}

			let a = try leaf("a")
			let b = try leaf("b")
			let c = try leaf("c")

			let left = try RepoFixture.block(
				RepoFixture.node(entries: [(key: Self.key("a"), value: a)])
			)
			let right = try RepoFixture.block(
				RepoFixture.node(entries: [(key: Self.key("c"), value: c)])
			)
			let root = try RepoFixture.block(
				RepoFixture.node(
					entries: [(key: Self.key("b"), value: b)],
					left: left.cid,
					subtrees: [Self.key("b"): right.cid]
				)
			)
			blocks.append(contentsOf: [left, right, root])

			self.archive = try CARv1(
				RepoFixture.car(root: root.cid, blocks: blocks)
			)
			self.root = root.cid
			self.values = [
				Self.key("a"): a, Self.key("b"): b, Self.key("c"): c,
			]
		}

		static func key(_ rkey: String) -> String {
			MerkleSearchTreeTests.collection + "/" + rkey
		}
	}

	@Test("every key in the tree is found, at the root and in both subtrees")
	func findsEachKey() throws {
		let tree = try Tree()

		for (key, expected) in tree.values {
			#expect(
				try MerkleSearchTree.find(
					key: key, root: tree.root, in: tree.archive)
					== expected,
				"looking up \(key)"
			)
		}
	}

	@Test(
		"a key that is not in the tree is refused rather than approximated",
		arguments: ["ab", "d", "", "a0"]
	)
	func rejectsAbsentKey(rkey: String) throws {
		let tree = try Tree()

		#expect(throws: Atproto.Repo.ProofError.recordNotInTree) {
			try MerkleSearchTree.find(
				key: Tree.key(rkey),
				root: tree.root,
				in: tree.archive
			)
		}
	}

	///Keys are stored with the shared prefix of the preceding key elided, so a
	///node holding several near-identical rkeys is where reconstruction goes
	///wrong if `p` is mishandled.
	@Test("prefix-compressed keys reconstruct correctly")
	func prefixCompression() throws {
		let rkeys = ["3lbwaaaa", "3lbwaaab", "3lbwaabb", "3lbxcccc", "zzz"]
		var blocks: [RepoFixture.Block] = []
		var entries: [(key: String, value: ContentIdentifier)] = []

		for rkey in rkeys {
			let block = try RepoFixture.block(.string(rkey))
			blocks.append(block)
			entries.append((key: Tree.key(rkey), value: block.cid))
		}

		let node = try RepoFixture.block(RepoFixture.node(entries: entries))
		blocks.append(node)
		let archive = try CARv1(RepoFixture.car(root: node.cid, blocks: blocks))

		//the fixture really is eliding prefixes, or this proves nothing
		let decoded = try archive.decoded(node.cid)
		let prefixes = try #require(decoded["e"]?.arrayValue).map {
			$0["p"]?.integerValue ?? -1
		}
		#expect(prefixes.contains { $0 > 0 })

		for (index, rkey) in rkeys.enumerated() {
			#expect(
				try MerkleSearchTree.find(
					key: Tree.key(rkey),
					root: node.cid,
					in: archive
				) == entries[index].value,
				"looking up \(rkey)"
			)
		}
	}

	@Test("a node whose keys do not ascend is malformed")
	func rejectsUnorderedEntries() throws {
		let value = try RepoFixture.block(.string("v"))
		//built by hand: two entries with p=0 whose keys descend
		let node = try RepoFixture.block(
			.map([
				(
					"e",
					.array([
						.map([
							("k", .bytes(Data("b".utf8))),
							("p", .integer(0)),
							("t", .null),
							("v", .link(value.cid)),
						]),
						.map([
							("k", .bytes(Data("a".utf8))),
							("p", .integer(0)),
							("t", .null),
							("v", .link(value.cid)),
						]),
					])
				),
				("l", .null),
			])
		)
		let archive = try CARv1(
			RepoFixture.car(root: node.cid, blocks: [value, node])
		)

		#expect(throws: Atproto.Repo.ProofError.mstNodeMalformed) {
			try MerkleSearchTree.find(key: "c", root: node.cid, in: archive)
		}
	}

	@Test("an entry claiming a longer shared prefix than exists is rejected")
	func rejectsPrefixOutOfRange() throws {
		let value = try RepoFixture.block(.string("v"))
		let node = try RepoFixture.block(
			.map([
				(
					"e",
					.array([
						.map([
							("k", .bytes(Data("a".utf8))),
							//nothing precedes this entry, so any prefix is a lie
							("p", .integer(4)),
							("t", .null),
							("v", .link(value.cid)),
						])
					])
				),
				("l", .null),
			])
		)
		let archive = try CARv1(
			RepoFixture.car(root: node.cid, blocks: [value, node])
		)

		#expect(throws: Atproto.Repo.ProofError.mstPrefixOutOfRange) {
			try MerkleSearchTree.find(key: "a", root: node.cid, in: archive)
		}
	}

	///A truncated proof — the server names a subtree it does not supply. This is
	///the realistic shape of an incomplete proof, and it must fail rather than
	///read as "not present".
	@Test("a subtree the CAR omits is a missing block, not an absent key")
	func rejectsOmittedSubtree() throws {
		let value = try RepoFixture.block(.string("v"))
		let orphan = try RepoFixture.block(.string("never included"))
		let node = try RepoFixture.block(
			RepoFixture.node(
				entries: [(key: Tree.key("m"), value: value.cid)],
				left: orphan.cid
			)
		)
		let archive = try CARv1(
			RepoFixture.car(root: node.cid, blocks: [value, node])
		)

		#expect(throws: Atproto.Repo.ProofError.missingBlock(orphan.cid.string)) {
			try MerkleSearchTree.find(
				key: Tree.key("a"),
				root: node.cid,
				in: archive
			)
		}
	}
}
