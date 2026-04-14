//
//  AnyRecordKey.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/13/26.
//

import AtprotoTypes
import Foundation
import Mockable

extension Atproto.AnyRecordKey: Mockable {
	//generate test did per the spec https://github.com/did-method-plc/did-method-plc
	static let lowercaseAlpha = (UInt8(ascii: "a")...UInt8(ascii: "z"))
		.map { Character(UnicodeScalar($0)) }

	static let numeric = (UInt8(ascii: "0")...UInt8(ascii: "9"))
		.map { Character(UnicodeScalar($0)) }
	static let base32Set: [Character] = lowercaseAlpha + numeric

	//for web
	static let uppercaseAlpha = (UInt8(ascii: "A")...UInt8(ascii: "Z"))
		.map { Character(UnicodeScalar($0)) }
	static let domainSet =
		lowercaseAlpha + uppercaseAlpha + numeric + [".", "-", "_", ":", "~"]

	public static func mock() -> Atproto.AnyRecordKey {
		.init(
			knownValue: String(
				(3...512).compactMap { _ in domainSet.randomElement() }
			)
		)
	}
}
