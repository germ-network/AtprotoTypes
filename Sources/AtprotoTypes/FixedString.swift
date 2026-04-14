//
//  FixedString.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/13/26.
//

import Foundation

///We have several places where JSON encoding expects a single value. This protocol
///is a hack on Codable that allows
///us to define a type that always encodes to the fixed value and only successfully decodes
///if the corresponding JSON value is equal to the fixed value

public protocol FixedString: Codable, Equatable, Sendable {
	static var fixedValue: String { get }
	init()
}

extension FixedString {
	public init(from decoder: any Decoder) throws {
		let container = try decoder.singleValueContainer()
		let string = try container.decode(String.self)
		guard string == Self.fixedValue else {
			throw Atproto.Errors.fixedStringMismatch
		}
		self.init()
	}

	public func encode(to encoder: any Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(Self.fixedValue)
	}
}
