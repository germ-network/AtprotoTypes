//
//  Mockable.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/12/26.
//

import Foundation

public protocol Mockable {
	static func mock() throws -> Self
}
