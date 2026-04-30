//
//  XRPCInterface.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 2/26/26.
//

import Foundation
import GermConvenience

///https://atproto.com/specs/xrpc
extension Atproto {
	public enum XRPC {
		//https://atproto.com/specs/lexicon#query-and-procedure-http-api
		public protocol Endpoint: ResponseParsing {
			associatedtype Id: EndpointId
			static var outputEncoding: HTTPContentType { get }

			associatedtype Parameters: QueryParametrizable
		}

		//Like RecordId, a NSID format used as an XRPC endpoint id
		//For procedures it's helpful for the collection to be a FixedString
		//for coding/decoding
		public protocol EndpointId: FixedString {
			static var nsid: NSID { get }
			init()
		}

		//these are GET queries
		public protocol Request: Endpoint {}

		//these are POST
		public protocol Procedure: Endpoint {
			associatedtype Input: ProcedureInput
		}

		//In the XRPC lexicon, parameter is optional
		public struct EmptyParameters: QueryParametrizable {
			public func asQueryItems() -> [URLQueryItem] {
				[]
			}

			public init() {}
		}

		public protocol ProcedureInput: Sendable {
			static var encoding: HTTPContentType { get }
			associatedtype Schema: Sendable
			static func encode(_: Schema) throws -> Data?
			var schema: Schema { get }
		}

		public struct EmptyInput: ProcedureInput {
			public static var encoding: HTTPContentType { .none }
			public static func encode(_: Schema) throws -> Data? { nil }
			public struct Schema: Sendable {}
			public var schema: Schema { .init() }
		}
	}
}

extension Atproto.XRPC.EndpointId {
	public static var fixedValue: String {
		nsid.rawValue
	}
}

public protocol QueryParametrizable: Sendable {
	func asQueryItems() -> [URLQueryItem]
}
