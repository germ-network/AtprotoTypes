//
//  ProxyService.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 3/29/26.
//

import Foundation

///https://atproto.com/specs/xrpc#service-proxying
public struct ProxyService {
	public let did: Atproto.DID
	public let endpoint: String

	public init(did: Atproto.DID, endpoint: String) {
		self.did = did
		self.endpoint = endpoint
	}

	public var headerValue: String {
		did.stringRepresentation + "#" + endpoint
	}
}
