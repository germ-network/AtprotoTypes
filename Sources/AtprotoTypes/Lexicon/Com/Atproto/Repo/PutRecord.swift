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
	public struct PutRecordNSID: Atproto.XRPC.EndpointId {
		public static var nsid: Atproto.NSID {
			.init(string: "com.atproto.repo.putRecord")
		}

		public init() {}
	}

	public enum PutRecord<Record: Atproto.Record>: Atproto.XRPC.Procedure {
		public typealias Id = PutRecordNSID
		public static var outputEncoding: HTTPContentType { .json }
		public static var contentTypeValue: HTTPContentType { .json }

		public struct Input: Atproto.XRPC.ProcedureInput {
			public static var encoding: HTTPContentType { .json }
			public static func encode(_ schema: Schema) throws -> Data? {
				try JSONEncoder().encode(schema)
			}

			public struct Schema: Codable, Sendable {
				public let repo: LexiconString.AtIdentifier
				public let collection: Record.Collection
				public let rkey: Record.Key
				public let record: Record
				let validate: Bool?
				let swapCommit: Atproto.CID?
				let swapRecord: Atproto.RecordSwap?

				public init(
					repo: LexiconString.AtIdentifier,
					rkey: Record.Key,
					record: Record,
					validate: Bool? = nil,
					swapCommit: Atproto.CID? = nil,
					swapRecord: Atproto.CID? = nil,
				) {
					self.repo = repo
					self.collection = .init()
					self.rkey = rkey
					self.record = record
					self.validate = validate
					self.swapCommit = swapCommit
					self.swapRecord = swapRecord.map { .record($0) }
				}

				/// `swap: .absent` encodes `"swapRecord": null`; `nil` omits it.
				public init(
					repo: LexiconString.AtIdentifier,
					rkey: Record.Key,
					record: Record,
					validate: Bool? = nil,
					swapCommit: Atproto.CID? = nil,
					swap: Atproto.RecordSwap?,
				) {
					self.repo = repo
					self.collection = .init()
					self.rkey = rkey
					self.record = record
					self.validate = validate
					self.swapCommit = swapCommit
					self.swapRecord = swap
				}

				/// The swap carried: `null` → `.absent`, a CID → `.record`, omitted → nil.
				public var swap: Atproto.RecordSwap? { swapRecord }

				private enum CodingKeys: String, CodingKey {
					case repo, collection, rkey, record, validate, swapCommit,
						swapRecord
				}

				public init(from decoder: any Decoder) throws {
					let container = try decoder.container(
						keyedBy: CodingKeys.self)
					repo = try container.decode(
						LexiconString.AtIdentifier.self, forKey: .repo)
					collection = try container.decode(
						Record.Collection.self, forKey: .collection)
					rkey = try container.decode(Record.Key.self, forKey: .rkey)
					record = try container.decode(Record.self, forKey: .record)
					validate = try container.decodeIfPresent(
						Bool.self, forKey: .validate)
					swapCommit = try container.decodeIfPresent(
						Atproto.CID.self, forKey: .swapCommit)
					// `decodeIfPresent` would collapse null and missing
					if container.contains(.swapRecord) {
						if try container.decodeNil(forKey: .swapRecord) {
							swapRecord = .absent
						} else {
							swapRecord = .record(
								try container.decode(
									Atproto.CID.self,
									forKey: .swapRecord))
						}
					} else {
						swapRecord = nil
					}
				}

				public func encode(to encoder: any Encoder) throws {
					var container = encoder.container(keyedBy: CodingKeys.self)
					try container.encode(repo, forKey: .repo)
					try container.encode(collection, forKey: .collection)
					try container.encode(rkey, forKey: .rkey)
					try container.encode(record, forKey: .record)
					try container.encodeIfPresent(validate, forKey: .validate)
					try container.encodeIfPresent(
						swapCommit, forKey: .swapCommit)
					switch swapRecord {
					case nil: break
					case .absent: try container.encodeNil(forKey: .swapRecord)
					case .record(let cid):
						try container.encode(cid, forKey: .swapRecord)
					}
				}
			}
			public let schema: Schema

			public init(schema: Schema) {
				self.schema = schema
			}
		}

		public typealias Parameters = Atproto.XRPC.EmptyParameters
		public typealias Output = PutRecordOutput
	}

	public struct PutRecordOutput: Codable, Sendable {
		public let uri: String
		public let cid: String
		public let commit: Defs.CommitMeta
		public let validationStatus: ValidationStatus

		public enum ValidationStatus: String, Sendable, Codable {
			case valid
			case unknown
		}

		public init(
			uri: String,
			cid: String,
			commit: Defs.CommitMeta,
			validationStatus: ValidationStatus
		) {
			self.uri = uri
			self.cid = cid
			self.commit = commit
			self.validationStatus = validationStatus
		}
	}
}

extension Lexicon.Com.Atproto.Repo.PutRecord: Atproto.XRPC.ResponseParsing {
	public static var badRequestErrors: Set<String> {
		defaultErrors.union(["InvalidSwap"])
	}
}
