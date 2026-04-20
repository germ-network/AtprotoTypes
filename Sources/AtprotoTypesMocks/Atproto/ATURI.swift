//
//  ATURI.swift
//  AtprotoTypesMocks
//
//  Created by Mark @ Germ on 4/20/26.
//

import AtprotoTypes
import Foundation
import Mockable

extension Atproto.ATURI: Mockable {
	public static func mock() -> Atproto.ATURI {
		.init(
			rawValue: "at://did:web:example.com/example.collection.nsid/"
				+ UUID().uuidString)
	}
}
