//
//  DAGCBORDecoder.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import Foundation

///Strict DAG-CBOR. Every restriction the codec puts on plain CBOR is enforced
///rather than tolerated: one encoding per value, no indefinite lengths, string
///keys in canonical order, and tag 42 as the only tag.
///
///Strictness is not tidiness here. A lax reader is a second parser of the same
///bytes, and anywhere two parsers can disagree about what a repo says is
///somewhere a proof can be made to mean two things.
public enum DAGCBORDecoder {
	static let maxDepth = 128

	public static func decode(_ data: Data) throws -> DAGCBORValue {
		var reader = ByteReader(data)
		let value = try decodeValue(from: &reader, depth: 0)
		guard reader.isAtEnd else {
			throw Atproto.Repo.ProofError.trailingBytes
		}
		return value
	}

	static func decodeValue(
		from reader: inout ByteReader,
		depth: Int
	) throws -> DAGCBORValue {
		guard depth < maxDepth else {
			throw Atproto.Repo.ProofError.nestingTooDeep
		}

		let initial = try reader.readByte()
		let major = initial >> 5
		let additional = initial & 0x1F

		switch major {
		case 0:
			let value = try readArgument(additional, from: &reader)
			guard value <= UInt64(Int64.max) else {
				throw Atproto.Repo.ProofError.integerOutOfRange
			}
			return .integer(Int64(value))

		case 1:
			let value = try readArgument(additional, from: &reader)
			//encodes -1 - value, so anything past Int64.max underflows Int64.min
			guard value <= UInt64(Int64.max) else {
				throw Atproto.Repo.ProofError.integerOutOfRange
			}
			return .integer(-1 - Int64(value))

		case 2:
			let length = try readCount(additional, from: &reader)
			return .bytes(Data(try reader.read(length)))

		case 3:
			let length = try readCount(additional, from: &reader)
			let raw = try reader.read(length)
			guard let string = String(bytes: raw, encoding: .utf8) else {
				throw Atproto.Repo.ProofError.invalidUTF8
			}
			return .string(string)

		case 4:
			let count = try readCount(additional, from: &reader)
			var items: [DAGCBORValue] = []
			items.reserveCapacity(min(count, 256))
			for _ in 0..<count {
				items.append(try decodeValue(from: &reader, depth: depth + 1))
			}
			return .array(items)

		case 5:
			return try decodeMap(additional, from: &reader, depth: depth)

		case 6:
			let tag = try readArgument(additional, from: &reader)
			guard tag == 42 else {
				throw Atproto.Repo.ProofError.unsupportedTag(tag)
			}
			return .link(try decodeLink(from: &reader, depth: depth))

		case 7:
			return try decodeSimple(additional, from: &reader)

		default:
			throw Atproto.Repo.ProofError.unsupportedMajorType(major)
		}
	}

	static func decodeMap(
		_ additional: UInt8,
		from reader: inout ByteReader,
		depth: Int
	) throws -> DAGCBORValue {
		let count = try readCount(additional, from: &reader)
		var entries: [(key: String, value: DAGCBORValue)] = []
		entries.reserveCapacity(min(count, 64))
		var previousKey: String?

		for _ in 0..<count {
			let keyValue = try decodeValue(from: &reader, depth: depth + 1)
			guard case .string(let key) = keyValue else {
				throw Atproto.Repo.ProofError.nonStringMapKey
			}
			if let previousKey {
				if previousKey == key {
					throw Atproto.Repo.ProofError.duplicateMapKey(key)
				}
				guard canonicallyPrecedes(previousKey, key) else {
					throw Atproto.Repo.ProofError.unorderedMapKeys(
						previousKey, key)
				}
			}
			previousKey = key
			entries.append(
				(key: key, value: try decodeValue(from: &reader, depth: depth + 1))
			)
		}
		return .map(entries)
	}

	///Tag 42's content is a byte string holding the identity multibase prefix
	///(a single 0x00) followed by the binary CID. The leading zero is not
	///decoration — without it the bytes would be a bare CID and the link would
	///be ambiguous with a multibase-prefixed one.
	static func decodeLink(
		from reader: inout ByteReader,
		depth: Int
	) throws -> ContentIdentifier {
		let inner = try decodeValue(from: &reader, depth: depth + 1)
		guard case .bytes(let raw) = inner, raw.first == 0x00 else {
			throw Atproto.Repo.ProofError.badCIDLink
		}
		return try ContentIdentifier(bytes: raw.dropFirst())
	}

	static func decodeSimple(
		_ additional: UInt8,
		from reader: inout ByteReader
	) throws -> DAGCBORValue {
		switch additional {
		case 20: return .bool(false)
		case 21: return .bool(true)
		case 22: return .null
		//DAG-CBOR pins floats to 64-bit, so half and single precision are not
		//alternate spellings we accept
		case 27:
			let raw = try reader.read(8)
			var bits: UInt64 = 0
			for byte in raw { bits = (bits << 8) | UInt64(byte) }
			return .float(Double(bitPattern: bits))
		default:
			throw Atproto.Repo.ProofError.unsupportedSimpleValue(additional)
		}
	}

	///Reads the argument for majors 0-6, rejecting any encoding longer than the
	///value needs.
	static func readArgument(
		_ additional: UInt8,
		from reader: inout ByteReader
	) throws -> UInt64 {
		switch additional {
		case 0...23:
			return UInt64(additional)
		case 24:
			let value = UInt64(try reader.readByte())
			guard value >= 24 else { throw Atproto.Repo.ProofError.nonMinimalLength }
			return value
		case 25:
			let value = try readBigEndian(2, from: &reader)
			guard value > 0xFF else { throw Atproto.Repo.ProofError.nonMinimalLength }
			return value
		case 26:
			let value = try readBigEndian(4, from: &reader)
			guard value > 0xFFFF else { throw Atproto.Repo.ProofError.nonMinimalLength }
			return value
		case 27:
			let value = try readBigEndian(8, from: &reader)
			guard value > 0xFFFF_FFFF else {
				throw Atproto.Repo.ProofError.nonMinimalLength
			}
			return value
		case 31:
			throw Atproto.Repo.ProofError.indefiniteLength
		default:
			throw Atproto.Repo.ProofError.reservedAdditionalInfo(additional)
		}
	}

	///An argument that has to be usable as a count, and that cannot describe
	///more content than the buffer actually holds — so a huge declared length
	///fails immediately instead of after an allocation.
	static func readCount(
		_ additional: UInt8,
		from reader: inout ByteReader
	) throws -> Int {
		let value = try readArgument(additional, from: &reader)
		guard value <= UInt64(Int.max), Int(value) <= reader.remaining else {
			throw Atproto.Repo.ProofError.truncated
		}
		return Int(value)
	}

	static func readBigEndian(
		_ count: Int,
		from reader: inout ByteReader
	) throws -> UInt64 {
		var value: UInt64 = 0
		for byte in try reader.read(count) {
			value = (value << 8) | UInt64(byte)
		}
		return value
	}

	///RFC 7049 canonical order — shorter keys first, then bytewise — which is
	///what DAG-CBOR kept and what the JS and Go implementations both emit. Note
	///this is *not* RFC 8949's plain bytewise ordering.
	static func canonicallyPrecedes(_ lhs: String, _ rhs: String) -> Bool {
		let left = Array(lhs.utf8)
		let right = Array(rhs.utf8)
		if left.count != right.count {
			return left.count < right.count
		}
		return left.lexicographicallyPrecedes(right)
	}
}
