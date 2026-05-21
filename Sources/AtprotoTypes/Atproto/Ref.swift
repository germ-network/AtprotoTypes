//
//  Ref.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 5/20/26.
//

import Foundation

//https://atproto.com/specs/lexicon#ref
extension Atproto {
	public struct Ref: StringRepresentable, Codable {
		public init(string: String) {
			self.rawValue = string
		}
		public private(set) var rawValue: String
	}
}
