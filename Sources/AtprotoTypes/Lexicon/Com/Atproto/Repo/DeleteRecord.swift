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
	public struct DeleteRecordNSID: Atproto.XRPC.EndpointId {
		public static var nsid: Atproto.NSID {
			.init(string: "com.atproto.repo.deleteRecord")
		}

		public init() {}
	}

	public enum DeleteRecord<Record: Atproto.Record>: Atproto.XRPC.Procedure {
		public typealias Id = DeleteRecordNSID
		public static var outputEncoding: HTTPContentType { .json }

		public struct Input: Atproto.XRPC.ProcedureInput {
			public static var encoding: HTTPContentType { .json }
			public static func encode(_ schema: Schema) throws -> Data? {
				try JSONEncoder().encode(schema)
			}

			public struct Schema: Encodable, Sendable {
				let repo: LexiconString.AtIdentifier
				let collection: Record.Collection
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
					self.collection = .init()
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

		public typealias Parameters = Atproto.XRPC.EmptyParameters
		public typealias Output = DeleteRecordOutput
	}

	public struct DeleteRecordOutput: Codable, Sendable {
		public let commit: Defs.CommitMeta

		public init(commit: Defs.CommitMeta) {
			self.commit = commit
		}
	}
}

extension Lexicon.Com.Atproto.Repo.DeleteRecord: Atproto.XRPC.ResponseParsing {
	public static var badRequestErrors: Set<String> {
		defaultErrors.union(["InvalidSwap"])
	}
}
