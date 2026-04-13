// The Swift Programming Language
// https://docs.swift.org/swift-book

public enum Atproto {
	///https://atproto.com/specs/nsid
	public typealias NSID = String

	///https://atproto.com/specs/at-uri-scheme
	public typealias ATURI = String

	public protocol Record: Sendable, Codable, Mockable {
		static var nsid: String { get }
		associatedtype Key: LexiconTypes.RecordKey
	}
}
