//
//  DeleteRecord.swift
//  AtprotoTypes
//
//  Created by Anna @ Germ on 4/2/26.
//

import Foundation
import GermConvenience

///https://docs.bsky.app/docs/api/com-atproto-repo-delete-record
///https://lexicon.garden/lexicon/did:plc:6msi3pj7krzih5qxqtryxlzw/com.atproto.repo.deleteRecord/docs
extension Lexicon.Com.Atproto.Repo {
	public static let deleteRecordNSID: Atproto.NSID = "com.atproto.repo.deleteRecord"

	public enum DeleteRecord<Record: AtprotoRecord>: XRPCProcedure {
		public static var nsid: Atproto.NSID { deleteRecordNSID }
		public static var outputEncoding: HTTPContentType { .json }

		public struct Input: XRPCProcedureInput {
			public static var encoding: HTTPContentType { .json }
			public static func encode(_ schema: Schema) throws -> Data? {
				try JSONEncoder().encode(schema)
			}

			public struct Schema: Encodable, Sendable {
				let repo: AtIdentifier
				let collection: Atproto.NSID
				let rkey: Record.Key?
				let swapRecord: CID?
				let swapCommit: CID?

				public init(
					repo: AtIdentifier,
					rkey: Record.Key,
					swapRecord: CID? = nil,
					swapCommit: CID? = nil,
				) {
					self.repo = repo
					self.collection = Record.nsid
					self.rkey = rkey
					self.swapRecord = swapRecord
					self.swapCommit = swapCommit
				}
			}
			public let schema: Schema

			public init(schema: Schema) {
				self.schema = schema
			}
		}

		public typealias Parameters = EmptyXRPCParameters
		public typealias Output = DeleteRecordResult
	}

	public struct DeleteRecordResult: Decodable, Sendable {
		public let commit: CommitMeta
	}

	public struct CommitMeta: Decodable, Sendable {
		public let cid: CID
		public let rev: Atproto.TID
	}
}

extension Lexicon.Com.Atproto.Repo.DeleteRecord: XRPCResponseParsing {
	public static var badRequestErrors: Set<String> {
		defaultErrors.union(["InvalidSwap"])
	}
}

extension Lexicon.Com.Atproto.Repo.DeleteRecord.Output: Mockable {
	public static func mock() -> Lexicon.Com.Atproto.Repo.DeleteRecordResult {
		.init(commit: .init(cid: .mock(), rev: .mock()))
	}
}
