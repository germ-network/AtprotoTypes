//
//  ATURI.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/14/26.
//

import Foundation

extension Atproto {
	///https://atproto.com/specs/at-uri-scheme

	/// In current atproto Lexicon use, the query and fragment parts are not yet supported, and only
	/// a fixed pattern of paths are allowed: "at://" AUTHORITY [ "/" COLLECTION [ "/" RKEY ] ]
	///
	/// The authority section is required, and should be normalized.
	/// Similar to the rules for DID syntax elsewhere in atproto, it is syntaxtually valid to have AT URIs
	/// with unsupported DID methods, though the URI will not resolve or function properly.
	///
	/// The optional collection part of the path must be a normalized NSID.
	/// The optional rkey part of the path must be a valid record key.
	public struct ATURI: StringRepresentable, Sendable, Codable {
		public static let prefix: String = "at://"

		public let authority: LexiconString.AtIdentifier
		public let collection: NSID?
		public let recordKey: AnyRecordKey?

		public var rawValue: String {
			var atURI = ATURI.prefix + authority.rawValue
			if let collection {
				atURI.append("/" + collection.rawValue)
			}
			if let recordKey {
				atURI.append("/" + recordKey.rawValue)
			}
			return atURI
		}

		public init(string: String) throws {
			guard string.hasPrefix(ATURI.prefix) else {
				throw Errors.missingAtPrefix
			}

			// Should be [ AUTHORITY, COLLECTION, RKEY ]
			let components = string.trimmingPrefix(ATURI.prefix)
				.split(separator: "/")

			guard !components.isEmpty else {
				throw Errors.missingAuthority
			}

			self.authority = try LexiconString.AtIdentifier(
				rawValue: String(components[0])
			).tryUnwrap
			self.collection =
				components.count >= 2
				? NSID(rawValue: String(components[1]))
				: nil
			self.recordKey =
				components.count >= 3
				? try AnyRecordKey(string: String(components[2]))
				: nil
		}

		public enum Errors: Error, LocalizedError {
			case missingAtPrefix
			case missingAuthority

			public var errorDescription: String {
				switch self {
				case .missingAtPrefix: "Missing at:// prefix"
				case .missingAuthority: "Missing authority"
				}
			}
		}
	}
}
