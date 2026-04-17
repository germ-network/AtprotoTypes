//
//  CreateRecord.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 3/19/26.
//

import Foundation
import GermConvenience

///https://docs.bsky.app/docs/api/com-atproto-repo-create-record
///https://lexicon.garden/lexicon/did:plc:6msi3pj7krzih5qxqtryxlzw/com.atproto.repo.createRecord/docs
extension Lexicon.Com.Atproto.Repo {
	public struct CreateRecordNSID: Atproto.XRPC.EndpointId {
		public static var nsid: Atproto.NSID {
			.init(rawValue: "com.atproto.repo.createRecord")
		}
		public init() {}
	}

	public enum CreateRecord<Record: Atproto.Record>: Atproto.XRPC.Procedure {
		public typealias Id = CreateRecordNSID
		public static var outputEncoding: HTTPContentType { HTTPContentType.json }

		public struct Input: Atproto.XRPC.ProcedureInput {
			public static var encoding: HTTPContentType { .json }
			public static func encode(_ schema: Schema) throws -> Data? {
				try JSONEncoder().encode(schema)
			}

			public struct Schema: Encodable, Sendable {
				let repo: LexiconString.AtIdentifier
				let collection: Id
				let rkey: Record.Key?
				let record: Record
				let validate: Bool?
				let swapCommit: Atproto.CID?

				public init(
					repo: LexiconString.AtIdentifier,
					rkey: Record.Key?,
					record: Record,
					validate: Bool? = nil,
					swapCommit: Atproto.CID? = nil,
				) {
					self.repo = repo
					self.rkey = rkey
					self.collection = .init()
					self.record = record
					self.validate = validate
					self.swapCommit = swapCommit
				}
			}
			public let schema: Schema

			public init(schema: Schema) {
				self.schema = schema
			}
		}

		public typealias Parameters = Atproto.XRPC.EmptyParameters
		
		//technically defined in the CreateRecord lexicon but is
		//for now identical to PutRecordResult
		public typealias Output = PutRecordResult
	}
}

extension Lexicon.Com.Atproto.Repo.CreateRecord: Atproto.XRPC.ResponseParsing {
	public static var badRequestErrors: Set<String> {
		defaultErrors.union(["InvalidSwap"])
	}
}
