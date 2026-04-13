// The Swift Programming Language
// https://docs.swift.org/swift-book

#if canImport(Mockable)
	import Mockable
#endif

public enum Atproto {
	///https://atproto.com/specs/nsid
	public typealias NSID = String

	///https://atproto.com/specs/at-uri-scheme
	public typealias ATURI = String

	#if canImport(Mockable)
		public protocol Record: Sendable, Codable, Mockable {
			static var nsid: String { get }
			associatedtype Key: LexiconTypes.RecordKey
		}
	#else
		public protocol Record: Sendable, Codable {
			static var nsid: String { get }
			associatedtype Key: LexiconTypes.RecordKey
		}
	#endif
}
