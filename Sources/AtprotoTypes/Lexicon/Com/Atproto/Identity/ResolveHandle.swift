//
//  ResolveHandle.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 5/1/26.
//

import Foundation
import GermConvenience

extension Lexicon.Com.Atproto {
	public enum Identity {}
}

///https://github.com/bluesky-social/atproto/blob/main/lexicons/com/atproto/identity/resolveHandle.json
extension Lexicon.Com.Atproto.Identity {
	public struct ResolveHandle: Atproto.XRPC.Request {
		public struct Id: Atproto.XRPC.EndpointId {
			public static var nsid: Atproto.NSID {
				.init(string: "com.atproto.identity.resolveHandle")
			}
			public init() {}
		}

		public struct Parameters: QueryParametrizable {
			public let handle: Atproto.Handle

			public init(handle: Atproto.Handle) {
				self.handle = handle
			}

			public func asQueryItems() -> [URLQueryItem] {
				[.init(name: "handle", value: handle.rawValue)]
			}
		}

		public static var outputEncoding: HTTPContentType { .json }

		public struct Output: Sendable, Codable {
			public let did: Atproto.DID
		}

		public static var badRequestErrors: Set<String> {
			defaultErrors.union(["HandleNotFound"])
		}
	}
}
