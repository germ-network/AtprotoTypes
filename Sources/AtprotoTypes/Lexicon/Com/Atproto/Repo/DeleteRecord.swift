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

	public enum DeleteRecord<Record: Atproto.Record>: XRPCProcedure {
		public static var nsid: Atproto.NSID { deleteRecordNSID }
		public static var outputEncoding: HTTPContentType { .json }

		public struct Input: XRPCProcedureInput {
			public static var encoding: HTTPContentType { .json }
			public static func encode(_ schema: Schema) throws -> Data? {
				try JSONEncoder().encode(schema)
			}

			public struct Schema: Encodable, Sendable {
				let repo: LexiconString.AtIdentifier
				let collection: Atproto.NSID
				let rkey: Record.Key
				let swapRecord: Atproto.CID?
				let swapCommit: Atproto.CID?

				public init(
					repo: LexiconString.AtIdentifier,
					rkey: Record.Key,
					swapRecord: Atproto.CID? = nil,
					swapCommit: Atproto.CID? = nil,
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

	public struct DeleteRecordResult: Codable, Sendable {
		public let commit: CommitMeta

		public init(commit: CommitMeta) {
			self.commit = commit
		}
	}

	public struct CommitMeta: Codable, Sendable {
		public let cid: Atproto.CID
		public let rev: Atproto.TID
		public init(cid: Atproto.CID, rev: Atproto.TID) {
			self.cid = cid
			self.rev = rev
		}
	}
}

extension Lexicon.Com.Atproto.Repo.DeleteRecord: XRPCResponseParsing {
	public static var badRequestErrors: Set<String> {
		defaultErrors.union(["InvalidSwap"])
	}
}
