//
//  TID.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/12/26.
//

import AtprotoTypes
import Foundation
import Mockable

extension Atproto.TID: Mockable {
	static let base32SortableCharacters = "234567abcdefghijklmnopqrstuvwxyz"

	static public func mock() -> Self {
		let prefix = Self.allowedPrefixCharacters.randomElement() ?? "2"
		let suffix = String(
			(1..<13).map { _ in base32SortableCharacters.randomElement() ?? "2" }
		)
		return .init(knownValue: [prefix] + suffix)
	}
}
