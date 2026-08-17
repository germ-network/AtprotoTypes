//
//  ByteReader.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import Foundation

///Cursor over untrusted bytes. Copies to `[UInt8]` up front so slice index
///arithmetic can't be got wrong — `Data`'s indices don't rebase on slicing, and
///every read here is attacker-influenced.
struct ByteReader {
	private let bytes: [UInt8]
	private(set) var offset: Int

	init(_ data: Data) {
		self.bytes = Array(data)
		self.offset = 0
	}

	var isAtEnd: Bool { offset >= bytes.count }
	var remaining: Int { bytes.count - offset }

	mutating func readByte() throws -> UInt8 {
		guard offset < bytes.count else {
			throw Atproto.Repo.ProofError.truncated
		}
		defer { offset += 1 }
		return bytes[offset]
	}

	mutating func read(_ count: Int) throws -> [UInt8] {
		guard count >= 0, remaining >= count else {
			throw Atproto.Repo.ProofError.truncated
		}
		defer { offset += count }
		return Array(bytes[offset..<(offset + count)])
	}

	///Unsigned LEB128 as multiformats uses it. Rejects both overflow and the
	///non-minimal encodings that would otherwise let the same number be written
	///two ways — which matters because CAR block framing is length-prefixed and
	///a second spelling of a length is a second parse of the same stream.
	mutating func readUnsignedVarint() throws -> UInt64 {
		var result: UInt64 = 0
		var shift: UInt64 = 0

		for index in 0..<10 {
			let byte = try readByte()
			let payload = UInt64(byte & 0x7F)

			guard shift < 64, !(shift == 63 && payload > 1) else {
				throw Atproto.Repo.ProofError.varintOverflow
			}
			result |= payload << shift

			if byte & 0x80 == 0 {
				//a trailing continuation-free zero byte adds nothing, so it is
				//a second spelling of a shorter varint
				guard index == 0 || byte != 0 else {
					throw Atproto.Repo.ProofError.varintNotMinimal
				}
				return result
			}
			shift += 7
		}
		throw Atproto.Repo.ProofError.varintOverflow
	}

	///Reads a length that has to be usable as an `Int` index.
	mutating func readLength() throws -> Int {
		let value = try readUnsignedVarint()
		guard value <= UInt64(Int.max), Int(value) <= remaining else {
			throw Atproto.Repo.ProofError.truncated
		}
		return Int(value)
	}
}
