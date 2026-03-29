//
//  XRPCInterface.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 2/26/26.
//

import Foundation
import GermConvenience

///https://atproto.com/specs/xrpc
public protocol XRPC: XRPCResponseParsing {
	static var nsid: Atproto.NSID { get }
	static var acceptValue: HTTPContentType { get }

	associatedtype Parameters: QueryParametrizable
}

//these are GET queries
public protocol XRPCRequest: XRPC {}

public protocol QueryParametrizable: Sendable {
	func asQueryItems() -> [URLQueryItem]
}

//these are POST
public protocol XRPCProcedure: XRPC {
	associatedtype Input: XRPCProcedureInput
}

public struct EmptyXRPCParameters: QueryParametrizable {
	public func asQueryItems() -> [URLQueryItem] {
		[]
	}

	public init() {}
}

public protocol XRPCProcedureInput: Sendable {
	static var encoding: HTTPContentType { get }
	associatedtype Schema: Sendable
	static func encode(_: Schema) throws -> Data?
	var schema: Schema { get }
}

public struct EmptyXRPCInput: XRPCProcedureInput {
	public static var encoding: HTTPContentType { .none }
	public static func encode(_: Schema) throws -> Data? { nil }
	public struct Schema: Sendable {}
	public var schema: Schema { .init() }
}
