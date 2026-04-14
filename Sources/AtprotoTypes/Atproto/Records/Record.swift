//
//  Record.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/14/26.
//

extension Atproto {
	public protocol Record: Sendable, Codable {
		associatedtype Id: RecordId
		associatedtype Key: RecordKey
	}

	//whereas NSID defines a structure, RecordId is a NSID used as
	//a collection id
	public protocol RecordId: FixedString {
		static var nsid: NSID { get }
		init()
	}
}

//default implementations for FixedString and Codable
extension Atproto.RecordId {
	static public var fixedValue: String { nsid.rawValue }
}
