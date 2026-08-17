//
//  CARv1.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import Foundation

///CAR v1: a varint-length-prefixed DAG-CBOR header, then varint-length-prefixed
///blocks each carrying its own CID.
///
///A record proof is one of these — the commit, the MST nodes along the path to
///the record, and the record block. That is what the JSON
///`com.atproto.repo.getRecord` a JSON-only caller uses throws away.
///
///The bytes originate from `com.atproto.sync.getRecord` at the DID's PDS, but a
///caller is not expected to make that call directly: a monitor performs it,
///verifies it, and serves the stored CAR from its own `/records/{did}`. Either
///way the check below is identical, which is why nothing here knows about
///transport.
public struct CARv1: Sendable {
	public let roots: [ContentIdentifier]
	private let blocks: [Data: Data]

	///Every block is checked against its own CID as it is read. Doing it here
	///rather than at lookup means a block that does not hash to its address can
	///never be observed by the walk at all, so no later code has to remember to
	///ask.
	public init(_ data: Data) throws {
		var reader = ByteReader(data)

		let headerLength = try reader.readLength()
		let headerBytes = Data(try reader.read(headerLength))
		let header = try DAGCBORDecoder.decode(headerBytes)

		guard let version = header["version"]?.integerValue else {
			throw Atproto.Repo.ProofError.badCARHeader
		}
		guard version == 1 else {
			throw Atproto.Repo.ProofError.unsupportedCARVersion(UInt64(clamping: version))
		}
		guard let rawRoots = header["roots"]?.arrayValue else {
			throw Atproto.Repo.ProofError.badCARHeader
		}

		let roots = try rawRoots.map { entry -> ContentIdentifier in
			guard let link = entry.linkValue else {
				throw Atproto.Repo.ProofError.badCARHeader
			}
			return link
		}
		guard !roots.isEmpty else {
			throw Atproto.Repo.ProofError.noCARRoots
		}
		self.roots = roots

		var blocks: [Data: Data] = [:]
		while !reader.isAtEnd {
			let blockLength = try reader.readLength()
			let start = reader.offset
			let cid = try ContentIdentifier.read(from: &reader)
			let cidLength = reader.offset - start
			guard blockLength >= cidLength else {
				throw Atproto.Repo.ProofError.truncated
			}
			let payload = Data(try reader.read(blockLength - cidLength))

			guard cid.matches(block: payload) else {
				throw Atproto.Repo.ProofError.blockCIDMismatch(cid.string)
			}
			//a duplicate block is harmless: it hashed to the same CID, so it is
			//the same bytes
			blocks[cid.bytes] = payload
		}
		self.blocks = blocks
	}

	public func block(_ cid: ContentIdentifier) throws -> Data {
		guard let payload = blocks[cid.bytes] else {
			throw Atproto.Repo.ProofError.missingBlock(cid.string)
		}
		return payload
	}

	public func decoded(_ cid: ContentIdentifier) throws -> DAGCBORValue {
		try DAGCBORDecoder.decode(try block(cid))
	}

	public var blockCount: Int { blocks.count }
}
