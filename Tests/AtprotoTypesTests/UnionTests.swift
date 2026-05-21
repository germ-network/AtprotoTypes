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

		let encoded = try JSONEncoder().encode(result)

		let _ = try JSONDecoder().decode(
			[SimpleRelationshipResult].self,
			from: encoded
		)
	}

}

//taken from https://docs.bsky.app/docs/api/app-bsky-graph-get-relationships
enum SimpleRelationshipResult {
	case relationship(Relationships)
	case notFound(NotFoundActor)

	struct Relationships: Codable, Atproto.Schema {
		static var ref: Atproto.Ref {
			.init(string: "app.bsky.graph.defs#relationship")
		}
		//for encoding
		private(set) var ref: Atproto.Ref? = ref
		let did: Atproto.DID
		let blocking: Atproto.ATURI?
		let blockedBy: Atproto.ATURI?
		let following: Atproto.ATURI?
		let followedBy: Atproto.ATURI?
		let blockedByList: Atproto.ATURI?
		let blockingbyList: Atproto.ATURI?

		enum CodingKeys: String, CodingKey {
			case ref = "$type"
			case did
			case blocking
			case blockedBy
			case following
			case followedBy
			case blockedByList
			case blockingbyList
		}
	}

	struct NotFoundActor: Atproto.Schema {
		static var ref: Atproto.Ref {
			.init(string: "app.bsky.graph.defs#notFoundActor")
		}

		//for encoding
		private(set) var ref: Atproto.Ref? = ref
		public let actor: LexiconString.AtIdentifier
		var notFound: Bool = true

		public init(actor: LexiconString.AtIdentifier) {
			self.actor = actor
		}

		enum CodingKeys: String, CodingKey {
			case ref = "$type"
			case actor
			case notFound
		}
	}
}

extension SimpleRelationshipResult: LexiconUnion {
	static var members: [Atproto.Ref: any Atproto.Schema.Type] {
		[
			Relationships.ref: Relationships.self,
			NotFoundActor.ref: NotFoundActor.self,
		]
	}

	init(object: any Codable) throws {
		if let relationships = object as? Relationships {
			self = .relationship(relationships)
		} else if let notFound = object as? NotFoundActor {
			self = .notFound(notFound)
		} else {
			throw LexionUnionError.unknownObject
		}
	}

	func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		switch self {
		case .relationship(let relationships):
			try container.encode(relationships)
		case .notFound(let notFound):
			try container.encode(notFound)
		}
	}
}
