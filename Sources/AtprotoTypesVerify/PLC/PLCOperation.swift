//
//  PLCOperation.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 10/18/26.
//

import AtprotoTypes
import Foundation

extension Atproto.PLC {
	///A `did:plc` operation, parsed from the JSON text a log serves and
	///normalized to the regular `plc_operation` shape.
	///
	///Normalized, because a genesis operation may still be in the deprecated
	///legacy `create` format and every later step wants one shape: which keys
	///may sign the next operation, what the document renders, whether a
	///tombstone ends the log. The DID is derived from the *original* bytes,
	///though — the legacy format hashes as itself — so the parsed value keeps
	///them rather than the normalized view.
	struct Operation: Sendable {
		struct Service: Sendable, Hashable {
			let type: String
			let endpoint: String
		}

		enum Kind: Sendable {
			///A `plc_operation`. Whether it is a genesis or an update is the
			///log's business, not the operation's — position decides it, and an
			///enum case per position would admit a genesis that carries a
			///`prev` and an update that does not.
			case plcOperation
			///A genesis in the deprecated legacy `create` format.
			case legacyCreate
			case tombstone
		}

		let kind: Kind

		///Priority-ordered, highest authority first. For a legacy `create` this
		///is `[recoveryKey, signingKey]`, which is the conversion the method
		///specification leaves to the reader and the PMR wire specification
		///pins.
		///Parsed, not left as `did:key` strings: the only thing anyone does with
		///one is verify against it, and the method specification restricts this
		///list to secp256k1 and P-256 — unlike `verificationMethods`, whose keys
		///may be any syntactically valid `did:key` and so must not go through a
		///type that refuses the rest.
		///
		///The `did:key:` prefix is required *before* parsing, because
		///`RepoSigningKey` also takes a bare multibase string — the form a DID
		///document publishes its key in — while the method specification
		///serializes a rotation key as `did:key` and nothing else.
		let rotationKeys: [RepoSigningKey]

		///In the order the operation's JSON object listed them, because the
		///rendered document's `verificationMethod` array follows that order.
		let verificationMethods: [(key: String, value: String)]

		let alsoKnownAs: [String]

		///Likewise ordered as the JSON object listed them.
		let services: [(key: String, value: Service)]

		///The CID of the operation this one points back to, or `nil` for a
		///genesis. A CID value, not an IPLD link: the method specification
		///encodes `prev` as a *text* CID even in DAG-CBOR, so the bytes that get
		///hashed are `signed`'s and this is the parsed view of what they say.
		let prev: Atproto.CID?

		///base64url, unpadded, 64 raw `r‖s` bytes once decoded.
		let sig: String

		///The signed operation exactly as parsed, in source key order. Hashing
		///this gives the operation's CID; removing `sig` from it gives the
		///signature preimage.
		let signed: DAGCBORValue

		var unsigned: DAGCBORValue { signed.removing(key: "sig") }

		var isTombstone: Bool { kind == .tombstone }

		static func parse(json text: String) throws -> Operation {
			let value: DAGCBORValue
			do {
				value = try DAGCBORValue.parse(json: text)
			} catch {
				throw VerifyError.malformedOperation("\(error)")
			}
			guard case .map = value else {
				throw VerifyError.operationNotAMap
			}
			guard let type = value["type"]?.stringValue else {
				throw VerifyError.operationFieldMissing("type")
			}

			switch type {
			case "plc_operation": return try regular(from: value)
			case "create": return try legacyCreate(from: value)
			case "plc_tombstone": return try tombstone(from: value)
			default: throw VerifyError.unsupportedOperationType(type)
			}
		}

		private static func regular(from value: DAGCBORValue) throws -> Operation {
			Operation(
				kind: .plcOperation,
				rotationKeys: try parseRotationKeys(
					try requiredStringArray(value, "rotationKeys")),
				verificationMethods: try requiredStringMap(
					value, "verificationMethods"),
				alsoKnownAs: try requiredStringArray(value, "alsoKnownAs"),
				services: try requiredServices(value, "services"),
				prev: try requiredPrev(value),
				sig: try requiredString(value, "sig"),
				signed: value
			)
		}

		///The deprecated `create` format, converted to the regular shape.
		///
		///`prev` is read rather than assumed null. The format writes it as an
		///explicit null — a genesis points at nothing — so a create carrying a
		///predecessor is not something this format produces, and reading the
		///field lets the genesis rule refuse it rather than the conversion
		///quietly dropping it.
		///
		///The `handle` and `service` are taken as written rather than validated
		///or prefixed: this format predates the current handle grammar, and the
		///conversion only puts the `at://` scheme on the handle.
		private static func legacyCreate(from value: DAGCBORValue) throws -> Operation {
			let signingKey = try requiredString(value, "signingKey")
			let recoveryKey = try requiredString(value, "recoveryKey")
			let handle = try requiredString(value, "handle")
			let service = try requiredString(value, "service")

			return Operation(
				kind: .legacyCreate,
				rotationKeys: try parseRotationKeys([recoveryKey, signingKey]),
				verificationMethods: [(key: "atproto", value: signingKey)],
				alsoKnownAs: ["at://" + handle],
				services: [
					(
						key: "atproto_pds",
						value: Service(
							type: "AtprotoPersonalDataServer",
							endpoint: service)
					)
				],
				prev: try requiredPrev(value),
				sig: try requiredString(value, "sig"),
				signed: value
			)
		}

		private static func tombstone(from value: DAGCBORValue) throws -> Operation {
			guard let prev = try requiredPrev(value) else {
				throw VerifyError.operationFieldMalformed("prev")
			}
			return Operation(
				kind: .tombstone,
				rotationKeys: [],
				verificationMethods: [],
				alsoKnownAs: [],
				services: [],
				prev: prev,
				sig: try requiredString(value, "sig"),
				signed: value
			)
		}

		private static func parseRotationKeys(_ keys: [String]) throws -> [RepoSigningKey] {
			try keys.map { key in
				guard key.hasPrefix("did:key:") else {
					throw VerifyError.badRotationKey(key)
				}
				do {
					return try RepoSigningKey(multibase: key)
				} catch {
					throw VerifyError.badRotationKey(key)
				}
			}
		}

		private static func requiredString(
			_ value: DAGCBORValue, _ field: String
		) throws -> String {
			guard let raw = value[field] else {
				throw VerifyError.operationFieldMissing(field)
			}
			guard let text = raw.stringValue else {
				throw VerifyError.operationFieldMalformed(field)
			}
			return text
		}

		private static func requiredStringArray(
			_ value: DAGCBORValue, _ field: String
		) throws -> [String] {
			guard let raw = value[field] else {
				throw VerifyError.operationFieldMissing(field)
			}
			guard let items = raw.arrayValue else {
				throw VerifyError.operationFieldMalformed(field)
			}
			return try items.map {
				guard let text = $0.stringValue else {
					throw VerifyError.operationFieldMalformed(field)
				}
				return text
			}
		}

		private static func requiredStringMap(
			_ value: DAGCBORValue, _ field: String
		) throws -> [(key: String, value: String)] {
			guard let raw = value[field] else {
				throw VerifyError.operationFieldMissing(field)
			}
			guard case .map(let entries) = raw else {
				throw VerifyError.operationFieldMalformed(field)
			}
			return try entries.map {
				guard let text = $0.value.stringValue else {
					throw VerifyError.operationFieldMalformed(field)
				}
				return (key: $0.key, value: text)
			}
		}

		private static func requiredServices(
			_ value: DAGCBORValue, _ field: String
		) throws -> [(key: String, value: Service)] {
			guard let raw = value[field] else {
				throw VerifyError.operationFieldMissing(field)
			}
			guard case .map(let entries) = raw else {
				throw VerifyError.operationFieldMalformed(field)
			}
			return try entries.map {
				guard
					let type = $0.value["type"]?.stringValue,
					let endpoint = $0.value["endpoint"]?.stringValue
				else {
					throw VerifyError.operationFieldMalformed(field)
				}
				return (key: $0.key, value: Service(type: type, endpoint: endpoint))
			}
		}

		///`prev` is required to be present — the method specification says a null
		///predecessor is written as an explicit null rather than by omitting the
		///key — and is either null or a CID.
		private static func requiredPrev(_ value: DAGCBORValue) throws -> Atproto.CID? {
			guard let raw = value["prev"] else {
				throw VerifyError.operationFieldMissing("prev")
			}
			switch raw {
			case .null:
				return nil
			case .string(let text):
				guard let cid = try? Atproto.CID(string: text) else {
					throw VerifyError.operationFieldMalformed("prev")
				}
				return cid
			default:
				throw VerifyError.operationFieldMalformed("prev")
			}
		}
	}
}
