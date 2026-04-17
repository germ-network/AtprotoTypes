//
//  Service.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 3/29/26.
//

import Foundation

///https://atproto.com/specs/xrpc#service-proxying
extension Atproto {
	public struct Service: Equatable {
		public let did: Atproto.DID
		public let endpoint: String

		public init(did: Atproto.DID, endpoint: String) {
			self.did = did
			self.endpoint = endpoint
		}

		public init(string: String) throws {
			let components = string.split(separator: "#")
			guard components.count == 2 else {
				throw Atproto.Errors.invalidStringInput
			}

			self.did = try Atproto.DID(rawValue: String(components[0]))
				.tryUnwrap
			self.endpoint = String(components[1])
		}

		public var headerValue: String {
			did.rawValue + "#" + endpoint
		}
	}
}
