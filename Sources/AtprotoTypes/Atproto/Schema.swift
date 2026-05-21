//
//  Schema.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 5/20/26.
//

import Foundation

extension Atproto {
	public protocol Schema: Sendable, Codable {
		static var ref: Atproto.Ref { get }
	}
}
