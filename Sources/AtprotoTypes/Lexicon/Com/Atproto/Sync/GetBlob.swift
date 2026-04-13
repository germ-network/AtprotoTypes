//
//  GetBlob.swift
//  AtprotoTypes
//
//  Pulled in by Anna Mistele on 3/3/26.
//  Created by Christopher Jr Riley on 2024-05-20.
//

import Crypto
import Foundation
import GermConvenience

// https://docs.bsky.app/docs/api/com-atproto-sync-get-blob
// https://lexicon.garden/lexicon/did:plc:6msi3pj7krzih5qxqtryxlzw/com.atproto.sync.getBlob/docs
/// [github]: https://github.com/bluesky-social/atproto/blob/main/lexicons/com/atproto/sync/getBlob.json
extension Lexicon.Com.Atproto.Sync {
	public enum GetBlob: XRPCRequest {
		public static var nsid: Atproto.NSID { "com.atproto.sync.getBlob" }
		public static let outputEncoding: HTTPContentType = .any

		public struct Parameters: QueryParametrizable {
			/// The DID of the account.
			let did: LexiconString.AtIdentifier

			/// The CID of the blob to fetch.
			let cid: CID

			public init(
				did: LexiconString.AtIdentifier,
				cid: CID
			) {
				self.did = did
				self.cid = cid
			}

			public func asQueryItems() -> [URLQueryItem] {
				return [
					.init(name: "did", value: did.string),
					.init(name: "cid", value: cid.string),
				]
			}
		}
		public typealias Output = Data?
	}
}

extension Lexicon.Com.Atproto.Sync.GetBlob: XRPCResponseParsing {
	public static var badRequestErrors: Set<String> {
		defaultErrors.union(
			[
				"BlobNotFound",
				"RepoNotFound",
				"RepoTakendown",
				"RepoSuspended",
				"RepoDeactivated",
			]
		)
	}
}

extension Lexicon.Com.Atproto.Sync.GetBlob.Output: Mockable {
	public static func mock() -> Self {
		SymmetricKey(size: .bits256).dataRepresentation
	}
}
