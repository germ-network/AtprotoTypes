//
//  ContentIdentifier.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import Base32
import Crypto
import Foundation

///A CID we can actually compute with. `Atproto.CID` in AtprotoTypes holds the
///bytes opaquely and can render base32, which is all a JSON caller needs; a
///proof needs the parts, because the whole point is to recompute the digest
///from the block and compare rather than take the server's word for the link.
///
///Narrow on purpose — v1 only, two codecs, sha2-256 only. See
///`docs/dependency-choices.md` for why this isn't a multiformats library.
public struct ContentIdentifier: Sendable, Hashable {
	public enum Codec: UInt64, Sendable {
		case raw = 0x55
		case dagCBOR = 0x71
	}

	//multicodec sha2-256, and the only digest atproto uses
	static let sha2256: UInt64 = 0x12
	static let digestLength = 32

	public let codec: Codec
	public let digest: [UInt8]

	init(codec: Codec, digest: [UInt8]) throws {
		guard digest.count == Self.digestLength else {
			throw Atproto.Repo.ProofError.badDigestLength(digest.count)
		}
		self.codec = codec
		self.digest = digest
	}

	///CIDv1 binary: version ‖ codec ‖ multihash, each multiformats-varint
	///prefixed. This is the form that appears in CAR block headers and, behind
	///the identity-multibase byte, inside DAG-CBOR tag 42.
	public var bytes: Data {
		var out = Self.varint(1)
		out += Self.varint(codec.rawValue)
		out += Self.varint(Self.sha2256)
		out += Self.varint(UInt64(Self.digestLength))
		out += digest
		return Data(out)
	}

	///Base32 lower, `b`-prefixed, matching `Atproto.CID.string`.
	public var string: String {
		"b" + Base32.encode(bytes, options: .letterCase(.lower), .pad(false))
	}

	///The bridge back to the opaque, JSON-facing CID type. `Atproto.CID`'s byte
	///initialiser is `package`-scoped, which this target shares.
	public var atprotoCID: Atproto.CID {
		.init(bytes: bytes)
	}

	public static func compute(codec: Codec, block: Data) throws -> ContentIdentifier {
		try .init(codec: codec, digest: Array(SHA256.hash(data: block)))
	}

	///The check the whole design rests on: content addressing only means
	///anything if someone actually recomputes the address.
	public func matches(block: Data) -> Bool {
		Array(SHA256.hash(data: block)) == digest
	}

	static func read(from reader: inout ByteReader) throws -> ContentIdentifier {
		let version = try reader.readUnsignedVarint()
		//CIDv0 is a bare base58 sha256 multihash with no version prefix; atproto
		//is CIDv1 only, and silently accepting v0 would mean accepting a
		//different codec convention than the one we check against
		guard version == 1 else {
			throw Atproto.Repo.ProofError.unsupportedCIDVersion(version)
		}

		let rawCodec = try reader.readUnsignedVarint()
		guard let codec = Codec(rawValue: rawCodec) else {
			throw Atproto.Repo.ProofError.unsupportedCodec(rawCodec)
		}

		let hash = try reader.readUnsignedVarint()
		guard hash == Self.sha2256 else {
			throw Atproto.Repo.ProofError.unsupportedHash(hash)
		}

		let length = try reader.readUnsignedVarint()
		guard length == UInt64(Self.digestLength) else {
			throw Atproto.Repo.ProofError.badDigestLength(Int(clamping: length))
		}

		return try .init(codec: codec, digest: try reader.read(Self.digestLength))
	}

	init(bytes: Data) throws {
		var reader = ByteReader(bytes)
		self = try Self.read(from: &reader)
		guard reader.isAtEnd else {
			throw Atproto.Repo.ProofError.trailingBytes
		}
	}

	///Exposed package-wide so fixture-building test support in
	///AtprotoTypesVerifyMocks can frame CAR headers and block lengths without a
	///second LEB128 implementation.
	package static func varint(_ value: UInt64) -> [UInt8] {
		var remaining = value
		var out: [UInt8] = []
		repeat {
			var byte = UInt8(remaining & 0x7F)
			remaining >>= 7
			if remaining != 0 { byte |= 0x80 }
			out.append(byte)
		} while remaining != 0
		return out
	}
}
