//
//  Sync.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/12/26.
//

import AtprotoTypes
import Crypto
import Foundation
import Mockable

extension Lexicon.Com.Atproto.Sync.GetBlob.Output: Mockable {
	public static func mock() -> Self {
		SymmetricKey(size: .bits256).dataRepresentation
	}
}
