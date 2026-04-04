//
//  RecordKey+Self.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/3/26.
//

import Foundation

extension Atproto.RecordKey {
	static let literalSelf = Atproto.RecordKey(knownValue: "self")
}

public protocol SelfIdentifiedRecord: AtprotoRecord {}
