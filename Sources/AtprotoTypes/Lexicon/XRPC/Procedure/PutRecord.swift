//
//  PutRecord.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 2/27/26.
//

import Foundation
import GermConvenience

//https://docs.bsky.app/docs/api/com-atproto-repo-put-record
//https://lexicon.garden/lexicon/did:plc:6msi3pj7krzih5qxqtryxlzw/com.atproto.repo.putRecord
extension Lexicon.Com.Atproto.Repo {
	public static let putRecordNSID: Atproto.NSID = "com.atproto.repo.putRecord"

	public enum PutRecord<Record: AtprotoRecord>: XRPCProcedure {
		public static var nsid: Atproto.NSID { putRecordNSID }
		public static var outputEncoding: HTTPContentType { .json }
		public static var contentTypeValue: HTTPContentType { .json }

		public struct Input: XRPCProcedureInput {
			public static var encoding: HTTPContentType { .json }
			public static func encode(_ schema: Schema) throws -> Data? {
				try JSONEncoder().encode(schema)
			}

			public struct Schema: Codable, Sendable {
				let repo: AtIdentifier
				let collection: Atproto.NSID
				let rkey: Record.Key
				let record: Record
				let validate: Bool?
				let swapCommit: CID?
				let swapRecord: CID?

				public init(
					repo: AtIdentifier,
					rkey: Record.Key,
					record: Record,
					validate: Bool? = nil,
					swapCommit: CID? = nil,
					swapRecord: CID? = nil,
				) {
					self.repo = repo
					self.collection = Record.nsid
					self.rkey = rkey
					self.record = record
					self.validate = validate
					self.swapCommit = swapCommit
					self.swapRecord = swapRecord
				}
			}
			public let schema: Schema

			public init(schema: Schema) {
				self.schema = schema
			}
		}

		public typealias Parameters = EmptyXRPCParameters
		public typealias Output = PutRecordResult
	}

	public struct PutRecordResult: Decodable, Sendable {
		public let uri: String
		public let cid: String
		//commit: CommitMeta
		public let validationStatus: String
	}
}

extension Lexicon.Com.Atproto.Repo.PutRecord: XRPCResponseParsing {
	public static var badRequestErrors: Set<String> {
		defaultErrors.union(["InvalidSwap"])
	}
}

extension Lexicon.Com.Atproto.Repo.PutRecord.Output: Mockable {
	public static func mock() -> Lexicon.Com.Atproto.Repo.PutRecordResult {
		.init(uri: "example", cid: "example", validationStatus: "unknown")
	}
}
