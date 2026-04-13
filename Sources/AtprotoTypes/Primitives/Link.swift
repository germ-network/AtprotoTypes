//
//  Link.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/13/26.
//

import Foundation

//https://atproto.com/specs/data-model#data-types

extension Atproto.Primitive {
	public struct Link: Sendable, Codable, Equatable {
		static let type = "link"

		public let link: Atproto.CID

		enum CodingKeys: String, CodingKey {
			case link = "$link"
		}
	}
}
