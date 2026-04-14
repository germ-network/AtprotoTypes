//
//  DID.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/13/26.
//

import AtprotoTypes

extension Atproto.DID {
	static public func mock(method: Methods = .plc) -> Self {
		switch method {
		case .plc:
			mockPlc()
		case .web:
			mockWeb()
		}
	}

	static func mockPlc() -> Self {
		.init(
			method: .plc,
			identifier: .init(
				(0..<24).compactMap { _ in base32Set.randomElement() }
			)
		)
	}

	static func mockWeb() -> Self {
		let length = (1...253).randomElement() ?? 10

		return .init(
			method: .web,
			identifier: .init(
				(1..<length)
					.compactMap { _ in domainSet.randomElement() }

					+ ".test"
			)
		)
	}

	//generate test did per the spec https://github.com/did-method-plc/did-method-plc
	static let lowercaseAlpha = (UInt8(ascii: "a")...UInt8(ascii: "z"))
		.map { Character(UnicodeScalar($0)) }

	static let numeric = (UInt8(ascii: "2")...UInt8(ascii: "7"))
		.map { Character(UnicodeScalar($0)) }
	static let base32Set: [Character] = lowercaseAlpha + numeric

	//for web
	static let uppercaseAlpha = (UInt8(ascii: "A")...UInt8(ascii: "Z"))
		.map { Character(UnicodeScalar($0)) }
	static let domainSet = lowercaseAlpha + uppercaseAlpha + numeric + ["-"]
}
