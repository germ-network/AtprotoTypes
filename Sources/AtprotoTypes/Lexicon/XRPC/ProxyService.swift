//
//  ProxyService.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 3/29/26.
//

import Foundation

///https://atproto.com/specs/xrpc#service-proxying
public struct ProxyService: Equatable {
	public let did: Atproto.DID
	public let endpoint: String

	public init(did: Atproto.DID, endpoint: String) {
		self.did = did
		self.endpoint = endpoint
	}

	public init(string: String) throws {
		let components = string.split(separator: "#")
		guard components.count == 2 else {
			throw AtprotoTypeError.invalidStringInput
		}

		self.did = try Atproto.DID(string: String(components[0]))
		self.endpoint = String(components[1])
	}

	public var headerValue: String {
		did.stringRepresentation + "#" + endpoint
	}
}
