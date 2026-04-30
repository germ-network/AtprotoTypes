//
//  GetRecord.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 2/24/26.
//  Created by Christopher Jr Riley on 2024-05-20.
//

import Foundation
import GermConvenience

//https://docs.bsky.app/docs/api/com-atproto-repo-get-record
//https://lexicon.garden/lexicon/did:plc:6msi3pj7krzih5qxqtryxlzw/com.atproto.repo.getRecord/docs
/// [github]: https://github.com/bluesky-social/atproto/blob/main/lexicons/com/atproto/repo/getRecord.json
extension Lexicon.Com.Atproto.Repo {
	//want this to be accessible without specifying the result type
	public struct GetRecordNSID: Atproto.XRPC.EndpointId {
		public static var nsid: Atproto.NSID {
			.init(string: "com.atproto.repo.getRecord")
		}

		public init() {}
	}

	public enum GetRecord<Result: Atproto.Record>: Atproto.XRPC.Request {
		public typealias Id = GetRecordNSID
		public struct Output: Sendable, Codable {

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
		public static var outputEncoding: HTTPContentType { .json }

		public struct Parameters: QueryParametrizable {
			let repo: LexiconString.AtIdentifier
			let rkey: Result.Key
			let cid: Atproto.CID?

			public init(
				repo: LexiconString.AtIdentifier,
				rkey: Result.Key,
				cid: Atproto.CID?
			) {
				self.repo = repo
				self.rkey = rkey
				self.cid = cid
			}

			public func asQueryItems() -> [URLQueryItem] {
				var base: [URLQueryItem] = [
					.init(name: "repo", value: repo.rawValue),
					.init(
						name: "collection",
						value: Result.Collection.fixedValue),
					.init(name: "rkey", value: rkey.rawValue),
				]
				if let cid {
					base.append(.init(name: "cid", value: cid.string))
				}

				return base
			}
		}
	}
}

extension Lexicon.Com.Atproto.Repo.GetRecord: Atproto.XRPC.ResponseParsing {
	public static var badRequestErrors: Set<String> {
		defaultErrors.union(["RecordNotFound"])
	}
}
