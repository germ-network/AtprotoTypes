// The Swift Programming Language
// https://docs.swift.org/swift-book

public enum Atproto {
	///https://atproto.com/specs/at-uri-scheme
	public typealias ATURI = String

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
