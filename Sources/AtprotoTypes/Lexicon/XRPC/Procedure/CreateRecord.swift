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
	public static let createRecordNSID: Atproto.NSID = "com.atproto.repo.createRecord"

	public enum CreateRecord<Record: AtprotoRecord>: XRPCProcedure {
		public static var nsid: Atproto.NSID { createRecordNSID }
		public static var acceptValue: HTTPContentType { HTTPContentType.json }

		public struct Input: XRPCProcedureInput {
			public static var encoding: HTTPContentType { .json }
			public static func encode(_ schema: Schema) throws -> Data? {
				try JSONEncoder().encode(schema)
			}

			public struct Schema: Encodable {
				let repo: AtIdentifier
				let collection: Atproto.NSID
				let rkey: Atproto.RecordKey?
				let record: Record
				let validate: Bool?
				let swapCommit: CID?

				public init(
					repo: AtIdentifier,
					rkey: Atproto.RecordKey?,
					record: Record,
					validate: Bool? = nil,
					swapCommit: CID? = nil,
				) {
					self.repo = repo
					self.collection = Record.nsid
					self.rkey = rkey
					self.record = record
					self.validate = validate
					self.swapCommit = swapCommit
				}

				public func httpBody() throws -> Data {
					try JSONEncoder().encode(self)
				}
			}
		}

		public typealias Parameters = EmptyXRPCParameters
		public typealias Output = PutRecordResult
	}
}
