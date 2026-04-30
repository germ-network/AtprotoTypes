//
//  CID.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/27/26.
//

import AtprotoTypes
import Foundation
import Mockable

extension Atproto.CID: Mockable {
	static public func mock() -> Self {
		//TODO, mock the internal mechanics of CID
		.init(bytes: Data("bmock".utf8))

	}
}
