//
//  UnionTests.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 5/20/26.
//

import AtprotoTypes
import Foundation
import GermConvenience
import Testing

struct UnionTests {
	static let relationshipJsonString =
		"""
		[{\"did\":\"did:plc:kta7dqcqoamo5ixlajxbtjps\",\"following\":\"at://did:plc:4yvwfwxfz5sney4twepuzdu7/app.bsky.graph.follow/3meoz6k62qk2i\",\"$type\":\"app.bsky.graph.defs#relationship\"},{\"actor\":\"example.com\",\"notFound\":true,\"$type\":\"app.bsky.graph.defs#notFoundActor\"}
		]
		"""

	@Test func testUnion() async throws {
		let result = try JSONDecoder().decode(
			[SimpleRelationshipResult].self,
			from: Self.relationshipJsonString.utf8Data
		)
		print(result)
	}

}

//taken from //c
enum SimpleRelationshipResult {
	case relationship(Relationships)
	case notFound(NotFoundActor)

	struct Relationships: Codable, Sendable {
		let did: Atproto.DID
		let blocking: Atproto.ATURI?
		let blockedBy: Atproto.ATURI?
		let following: Atproto.ATURI?
		let followedBy: Atproto.ATURI?
		let blockedByList: Atproto.ATURI?
		let blockingbyList: Atproto.ATURI?
	}

	struct NotFoundActor: Codable, Sendable {
		public let actor: LexiconString.AtIdentifier
		var notFound: Bool = true

		public init(actor: LexiconString.AtIdentifier) {
			self.actor = actor
		}
	}
}

extension SimpleRelationshipResult: LexiconUnion {
	static func type(
		ref: Atproto.Ref
	) throws -> any Decodable.Type {
		switch ref.rawValue {
		case "app.bsky.graph.defs#relationship":
			Relationships.self
		case "app.bsky.graph.defs#notFoundActor":
			NotFoundActor.self
		default:
			throw LexionUnionError.unknownType(ref)
		}
	}

	init(object: any Decodable) throws {
		if let relationships = object as? Relationships {
			self = .relationship(relationships)
		} else if let notFound = object as? NotFoundActor {
			self = .notFound(notFound)
		} else {
			throw LexionUnionError.unknownObject
		}
	}
}
