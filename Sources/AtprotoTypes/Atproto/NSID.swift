//
//  NSID.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/13/26.
//

import Foundation

//https://atproto.com/specs/nsid
///The basic structure and semantics of an NSID are a fully-qualified hostname in reverse domain-name order, followed by an additional name segment. The hostname part is the domain authority, and the final segment is the name.

///This type expresses the structure and semantics of the NSID. It may be used in several different settings:
///Lexicon schemas for records, XRPC endpoints, and more.
extension Atproto {
	//	public typealias NSID = FixedString
	public struct NSID: RawRepresentable, Sendable {
		public init(rawValue: String) {
			self.rawValue = rawValue
		}
		public var rawValue: String
		//TODO: parse into domain authority and name, if needed
	}
}
