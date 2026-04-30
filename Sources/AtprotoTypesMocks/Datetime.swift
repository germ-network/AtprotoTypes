//
//  Datetime.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/29/26.
//

import AtprotoTypes
import Mockable

extension Atproto.Datetime: Mockable {
	static public func mock() -> Self {
		.init(date: .now)
	}
}
