//
//  File.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/29/26.
//

import AtprotoTypes
import Foundation
import Mockable

extension Atproto.Handle: Mockable {
	public static func mock() throws -> Atproto.Handle {
		try .init(string: "\(UUID().uuidString).example.com")
	}
}
