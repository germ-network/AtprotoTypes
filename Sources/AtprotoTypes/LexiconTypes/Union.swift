//
//  Union.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 5/20/26.
//

import Foundation

///This protocol provides default coding/encoding implementation for a union of a set of types known at
///compile time. See UnionTests for an example
///https://atproto.com/specs/lexicon#union
///
///This matches logically an enum and is likely most easily implemetned as an enum, however
///
///Currently implemented as a union of records but could be any lexicon schema
public protocol LexiconUnion: Codable, Sendable {
	static var members: [Atproto.Ref: any Atproto.Schema.Type] { get }
	
	init(object: any Codable) throws
}

enum TypeHeader: String, CodingKey {
	case type = "$type"
}

extension LexiconUnion {
	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: TypeHeader.self)
		let ref = try container.decode(Atproto.Ref.self, forKey: .type)
		
		let type = try Self.members[ref].tryUnwrap(
			LexionUnionError.unknownType(ref)
		)

		try self.init(object: try type.init(from: decoder))
	}
}

public enum LexionUnionError: LocalizedError {
	case unknownType(Atproto.Ref)
	case unknownObject

	public var errorDescription: String? {
		switch self {
		case .unknownType(let ref): "encountered unknown type \(ref)"
		case .unknownObject: "Unknown object"
		}
	}
}
