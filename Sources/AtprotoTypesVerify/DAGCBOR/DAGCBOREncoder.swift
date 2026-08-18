//
//  DAGCBOREncoder.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import Foundation

///Canonical DAG-CBOR out.
///
///Verification needs an encoder for exactly one reason: the commit signature
///covers the commit with its `sig` field removed, so the preimage has to be
///rebuilt rather than read. That makes `encode(decode(bytes)) == bytes` for
///canonical input the property the whole signature check leans on — it is
///pinned in the round-trip tests.
public enum DAGCBOREncoder {
	public static func encode(_ value: DAGCBORValue) -> Data {
		var out = Data()
		append(value, to: &out)
		return out
	}

	static func append(_ value: DAGCBORValue, to out: inout Data) {
		switch value {
		case .null:
			out.append(0xF6)

		case .bool(let flag):
			out.append(flag ? 0xF5 : 0xF4)

		case .integer(let number):
			if number >= 0 {
				appendHeader(major: 0, argument: UInt64(number), to: &out)
			} else {
				appendHeader(major: 1, argument: UInt64(-1 - number), to: &out)
			}

		case .float(let number):
			out.append(0xFB)
			appendBigEndian(number.bitPattern, width: 8, to: &out)

		case .bytes(let data):
			appendHeader(major: 2, argument: UInt64(data.count), to: &out)
			out.append(data)

		case .string(let string):
			let utf8 = Array(string.utf8)
			appendHeader(major: 3, argument: UInt64(utf8.count), to: &out)
			out.append(contentsOf: utf8)

		case .array(let items):
			appendHeader(major: 4, argument: UInt64(items.count), to: &out)
			for item in items { append(item, to: &out) }

		case .map(let entries):
			appendHeader(major: 5, argument: UInt64(entries.count), to: &out)
			//sorted rather than trusted: decode validates order, but a value
			//built in code (or with a key removed) should not be able to emit a
			//non-canonical map just because someone assembled it out of order
			let ordered = entries.sorted {
				DAGCBORDecoder.canonicallyPrecedes($0.key, $1.key)
			}
			for entry in ordered {
				append(.string(entry.key), to: &out)
				append(entry.value, to: &out)
			}

		case .link(let cid):
			appendHeader(major: 6, argument: 42, to: &out)
			//identity multibase prefix, then the binary CID
			var linkBytes = Data([0x00])
			linkBytes.append(cid.bytes)
			appendHeader(major: 2, argument: UInt64(linkBytes.count), to: &out)
			out.append(linkBytes)
		}
	}

	static func appendHeader(major: UInt8, argument: UInt64, to out: inout Data) {
		let prefix = major << 5
		switch argument {
		case 0...23:
			out.append(prefix | UInt8(argument))
		case 24...0xFF:
			out.append(prefix | 24)
			out.append(UInt8(argument))
		case 0x100...0xFFFF:
			out.append(prefix | 25)
			appendBigEndian(argument, width: 2, to: &out)
		case 0x1_0000...0xFFFF_FFFF:
			out.append(prefix | 26)
			appendBigEndian(argument, width: 4, to: &out)
		default:
			out.append(prefix | 27)
			appendBigEndian(argument, width: 8, to: &out)
		}
	}

	static func appendBigEndian(_ value: UInt64, width: Int, to out: inout Data) {
		for shift in stride(from: (width - 1) * 8, through: 0, by: -8) {
			out.append(UInt8((value >> UInt64(shift)) & 0xFF))
		}
	}
}
