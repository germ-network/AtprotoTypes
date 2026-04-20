//
//  ListRecords.swift
//  AtprotoTypes
//
//  Created by Anna Mistele on 3/2/26.
//

import Foundation
import GermConvenience

/// https://docs.bsky.app/docs/api/com-atproto-repo-list-records
/// https://lexicon.garden/lexicon/did:plc:6msi3pj7krzih5qxqtryxlzw/com.atproto.repo.listRecords/docs
/// [github]: https://github.com/bluesky-social/atproto/blob/main/lexicons/com/atproto/repo/listRecords.json
extension Lexicon.Com.Atproto.Repo {
	public struct ListRecordsNSID: Atproto.XRPC.EndpointId {
		public static var nsid: Atproto.NSID {
			.init(rawValue: "com.atproto.repo.listRecords")
		}

		public init() {}
	}

	public enum ListRecords<Result: Atproto.Record>: Atproto.XRPC.Request {
		public typealias Id = ListRecordsNSID
		public static var outputEncoding: HTTPContentType { .json }

		public struct Parameters: QueryParametrizable {
			let repo: LexiconString.AtIdentifier
			// TODO: Enforce min/max (1-100)?
			let limit: Int?
			let cursor: String?
			let reverse: Bool?

			public init(
				repo: LexiconString.AtIdentifier,
				limit: Int?,
				cursor: String?,
				reverse: Bool?
			) {
				self.repo = repo
				self.limit = limit
				self.cursor = cursor
				self.reverse = reverse
			}

			public func asQueryItems() -> [URLQueryItem] {
				var base: [URLQueryItem] = [
					.init(name: "repo", value: repo.rawValue),
					.init(name: "collection", value: Result.Id.fixedValue),
				]
				if let limit {
					base.append(.init(name: "limit", value: limit.description))
				}
				if let cursor {
					base.append(.init(name: "cursor", value: cursor))
				}
				if let reverse {
					base.append(
						.init(name: "reverse", value: reverse.description))
				}
				return base
			}
		}

		public struct Output: Sendable, Codable {
			public let cursor: String?
			public let records: [Record]

			public init(cursor: String?, records: [Record]) {
				self.cursor = cursor
				self.records = records
			}
		}

		/// From https://github.com/bluesky-social/atproto/blob/main/lexicons/com/atproto/repo/listRecords.json
		/// Same as the GetRecord output, but they're defined separately, so I'll leave them separate
		public struct Record: Sendable, Codable {
			/// The URI of the record.
			public let uri: Atproto.ATURI

			/// The CID hash for the record.
			public let cid: String

			/// The value for the record. Codable for later conversion
			public let value: Result

			public init(uri: Atproto.ATURI, cid: String, value: Result) {
				self.uri = uri
				self.cid = cid
				self.value = value
			}
		}
	}
}

extension Lexicon.Com.Atproto.Repo.ListRecords: Atproto.XRPC.ResponseParsing {
	public static var badRequestErrors: Set<String> {
		defaultErrors
	}
}
