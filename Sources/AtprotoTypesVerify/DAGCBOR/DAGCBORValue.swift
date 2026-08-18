//
//  DAGCBORValue.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import Foundation

///The IPLD data model, as much of it as DAG-CBOR admits.
///
///A generic value rather than `Codable` models of the commit and MST node,
///because verifying a commit signature means re-encoding the commit *minus its
///`sig`* and hashing that. Any field we didn't model would vanish in the
///round-trip and the preimage would be wrong — so the decode has to be
///lossless over the whole node, not just the parts we happen to read.
///
///This is also why a CBOR library doesn't substitute, strict or not — the ones
///worth considering are `Codable`-only. See `docs/dependency-choices.md`.
public indirect enum DAGCBORValue: Sendable, Hashable {
	case null
	case bool(Bool)
	case integer(Int64)
	case float(Double)
	case bytes(Data)
	case string(String)
	case array([DAGCBORValue])
	///Ordered, because DAG-CBOR fixes the key order and re-encoding has to
	///reproduce it. Decoding validates the order, so this is already canonical.
	case map([(key: String, value: DAGCBORValue)])
	case link(ContentIdentifier)

	public static func == (lhs: DAGCBORValue, rhs: DAGCBORValue) -> Bool {
		switch (lhs, rhs) {
		case (.null, .null): true
		case (.bool(let a), .bool(let b)): a == b
		case (.integer(let a), .integer(let b)): a == b
		case (.float(let a), .float(let b)): a.bitPattern == b.bitPattern
		case (.bytes(let a), .bytes(let b)): a == b
		case (.string(let a), .string(let b)): a == b
		case (.array(let a), .array(let b)): a == b
		case (.link(let a), .link(let b)): a == b
		case (.map(let a), .map(let b)):
			a.count == b.count
				&& zip(a, b).allSatisfy { $0.key == $1.key && $0.value == $1.value }
		default: false
		}
	}

	public func hash(into hasher: inout Hasher) {
		switch self {
		case .null: hasher.combine(0)
		case .bool(let value): hasher.combine(value)
		case .integer(let value): hasher.combine(value)
		case .float(let value): hasher.combine(value.bitPattern)
		case .bytes(let value): hasher.combine(value)
		case .string(let value): hasher.combine(value)
		case .array(let value): hasher.combine(value)
		case .link(let value): hasher.combine(value)
		case .map(let entries):
			for entry in entries {
				hasher.combine(entry.key)
				hasher.combine(entry.value)
			}
		}
	}
}

extension DAGCBORValue {
	public subscript(key: String) -> DAGCBORValue? {
		guard case .map(let entries) = self else { return nil }
		return entries.first { $0.key == key }?.value
	}

	public var stringValue: String? {
		guard case .string(let value) = self else { return nil }
		return value
	}

	public var integerValue: Int64? {
		guard case .integer(let value) = self else { return nil }
		return value
	}

	public var bytesValue: Data? {
		guard case .bytes(let value) = self else { return nil }
		return value
	}

	public var arrayValue: [DAGCBORValue]? {
		guard case .array(let value) = self else { return nil }
		return value
	}

	public var linkValue: ContentIdentifier? {
		guard case .link(let value) = self else { return nil }
		return value
	}

	///For the nullable link fields the repo format uses — `prev` on a commit,
	///`l` and `t` on an MST node. A missing key and an explicit null are the
	///same absence; anything else present is malformed rather than absent,
	///which is why this throws instead of returning nil.
	public static func optionalLink(
		_ value: DAGCBORValue?
	) throws -> ContentIdentifier? {
		switch value {
		case .none, .some(.null): nil
		case .some(.link(let cid)): cid
		default: throw Atproto.Repo.ProofError.mstNodeMalformed
		}
	}

	public func removing(key: String) -> DAGCBORValue {
		guard case .map(let entries) = self else { return self }
		return .map(entries.filter { $0.key != key })
	}
}
