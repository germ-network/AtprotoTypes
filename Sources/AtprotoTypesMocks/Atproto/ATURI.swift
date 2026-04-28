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
			authority: .init(
				knownDID: .init(
					knownIdentifier: "example.com",
					knownMethod: .web
				)
			),
			collection: .init(rawValue: "example.collection.nsid"),
			recordKey: .init(knownValue: UUID().uuidString)
		)
	}
}
