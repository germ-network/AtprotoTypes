//
//  MerkleSearchTree.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import Foundation

///The MST walk: from a signed commit's `data` root down to one key.
///
///A node is `{ e: [entries], l: left-subtree }`, and an entry is
///`{ p: shared-prefix-length, k: key-suffix, v: value, t: right-subtree }`.
///Keys are `collection/rkey`, stored bytewise-ascending with the shared prefix
///of the preceding key elided — so reconstructing a key means carrying the
///previous one, and a node that lies about `p` is the first thing to reject.
///
///The semantics are atproto's, not a generic Merkle tree's, so no general
///library applies. See `docs/dependency-choices.md`.
public enum MerkleSearchTree {
	enum Step {
		case found(ContentIdentifier)
		case descend(ContentIdentifier?)
	}

	///Returns the value CID the tree proves for `key`, or throws. There is no
	///"probably" — either the walk lands on the key or the record is not in the
	///repo at that path.
	public static func find(
		key: String,
		root: ContentIdentifier,
		in car: CARv1
	) throws -> ContentIdentifier {
		let target = Array(key.utf8)
		var current = root
		//a proof is a DAG the server chose; nothing stops it pointing a node at
		//an ancestor, and an unbounded walk would then never return
		var visited: Set<Data> = []

		while true {
			guard visited.insert(current.bytes).inserted else {
				throw Atproto.Repo.ProofError.mstCycle
			}

			switch try step(node: try car.decoded(current), target: target) {
			case .found(let value):
				return value
			case .descend(let next):
				guard let next else {
					throw Atproto.Repo.ProofError.recordNotInTree
				}
				current = next
			}
		}
	}

	static func step(node: DAGCBORValue, target: [UInt8]) throws -> Step {
		guard let entries = node["e"]?.arrayValue else {
			throw Atproto.Repo.ProofError.mstNodeMalformed
		}

		//the subtree covering keys below the entry currently being considered:
		//the node's own `l` before any entry, then each entry's `t` after it
		var subtree = try DAGCBORValue.optionalLink(node["l"])
		var previousKey: [UInt8] = []
		var isFirst = true

		for entry in entries {
			guard let prefix = entry["p"]?.integerValue,
				let suffix = entry["k"]?.bytesValue,
				let value = entry["v"]?.linkValue
			else {
				throw Atproto.Repo.ProofError.mstNodeMalformed
			}
			guard prefix >= 0, Int(prefix) <= previousKey.count else {
				throw Atproto.Repo.ProofError.mstPrefixOutOfRange
			}

			var fullKey = Array(previousKey[0..<Int(prefix)])
			fullKey.append(contentsOf: suffix)

			//keys ascend strictly, and the walk's "not here, and not to the
			//left either" conclusion is only sound if they do
			guard isFirst || previousKey.lexicographicallyPrecedes(fullKey) else {
				throw Atproto.Repo.ProofError.mstNodeMalformed
			}
			isFirst = false

			if fullKey == target {
				return .found(value)
			}
			if target.lexicographicallyPrecedes(fullKey) {
				return .descend(subtree)
			}

			subtree = try DAGCBORValue.optionalLink(entry["t"])
			previousKey = fullKey
		}

		//past every entry in this node, so the key can only be in the subtree
		//hanging off the last one
		return .descend(subtree)
	}
}
