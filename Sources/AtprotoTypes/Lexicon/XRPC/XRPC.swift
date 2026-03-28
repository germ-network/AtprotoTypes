//
//  XRPCInterface.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 2/26/26.
//

import Foundation

///https://atproto.com/specs/xrpc
public protocol XRPC: Sendable {
	static var nsid: Atproto.NSID { get }
	static var acceptValue: String { get }

	associatedtype Parameters: QueryParameters
	associatedtype Output: Decodable, Mockable, Sendable
}

//these are GET queries
public protocol XRPCRequest: XRPC {}

public protocol QueryParameters: Sendable {
	func asQueryItems() -> [URLQueryItem]
}

//these are POST
public protocol XRPCProcedure: XRPC {
	static var contentTypeValue: String { get }

	associatedtype BodyParameters: HTTPBodyEncodable
}

public struct EmptyParameters: QueryParameters {
	public func asQueryItems() -> [URLQueryItem] {
		[]
	}

	public init() {}
}

public protocol HTTPBodyEncodable: Sendable {
	func httpBody() throws -> Data
}
