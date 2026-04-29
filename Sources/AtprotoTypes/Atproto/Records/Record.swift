//
//  Record.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/14/26.
//

extension Atproto {
	public protocol Record: Sendable, Codable {
		associatedtype Collection: RecordType
		associatedtype Key: RecordKey

		//reminder to make a public private(set) var for encoding/decodind
		var nsid: Collection { get }
	}

	//whereas NSID defines a structure, RecordId is a NSID used as
	//a collection id
	public protocol RecordType: FixedString, Codable {
		static var nsid: NSID { get }
		init()
	}
}

//default implementations for FixedString and Codable
extension Atproto.RecordType {
	static public var fixedValue: String { nsid.rawValue }
}
