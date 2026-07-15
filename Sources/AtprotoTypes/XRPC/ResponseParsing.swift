//
//  ResponseParsing.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 3/29/26.
//

import Foundation
import GermConvenience

import struct HTTPTypes.HTTPResponse

extension Atproto.XRPC {
	public protocol ResponseParsing: Sendable {
		associatedtype Output: Decodable, Sendable
		//this is defined in the lexicon, and additionally in the api spec
		static var badRequestErrors: Set<String> { get }
		static var recognizedStatuses: Set<HTTPResponse.Status> { get }
	}

	public struct EmptyOutput: Decodable, Sendable {
		public init() {}
	}
}

//default
extension Atproto.XRPC.ResponseParsing {
	static public var recognizedStatuses: Set<HTTPResponse.Status> {
		[.badRequest, .unauthorized]
	}

	static public var defaultErrors: Set<String> {
		["InvalidRequest", "ExpiredToken", "InvalidToken"]
	}
}

extension Atproto.XRPC {
	public enum ParsedResponse<Output: Decodable> {
		case ok(Output)
		case error(ParseError)

		public var output: Output {
			get throws {
				switch self {
				case .ok(let output):
					output
				case .error(let parseXRPCError):
					throw parseXRPCError
				}
			}
		}
	}
}

extension Atproto.XRPC {
	public enum ParseError: LocalizedError {
		case xrpcError(
			status: HTTPResponse.Status,
			error: ErrorResponse
		)
		case unrecognized(HTTPResponse)
		//A recognized status whose body failed to decode. Distinct from .unrecognized
		//so a well-formed 200 with an undecodable body (e.g. a record whose format
		//drifted) keeps its DecodingError — coding path and all — instead of being
		//reported identically to an unknown status.
		case undecodable(HTTPResponse, underlying: any Error)

		public var errorDescription: String? {
			switch self {
			case .xrpcError(let status, let error):
				"\(status): \(error.error)"
			case .unrecognized(let response):
				"Unrecognized response: \(response)"
			case .undecodable(let response, let underlying):
				"Undecodable response: \(response), underlying: \(underlying)"
			}
		}
	}
}

extension Atproto.XRPC.ResponseParsing {
	public static func parse(
		fullResponse: HTTPDataResponse
	) throws -> Atproto.XRPC.ParsedResponse<Output> {
		do {
			switch fullResponse.response.status {
			case .ok:
				return .ok(try parseSuccess(body: fullResponse.data))
			case .badRequest:
				let errorObject = try JSONDecoder.atproto
					.decode(
						Atproto.XRPC.ErrorResponse.self,
						from: fullResponse.data
					)
				if Self.badRequestErrors.contains(errorObject.error) {
					return .error(
						.xrpcError(status: .badRequest, error: errorObject)
					)
				}
			case let status where Self.recognizedStatuses.contains(status):
				let errorObject = try JSONDecoder.atproto
					.decode(
						Atproto.XRPC.ErrorResponse.self,
						from: fullResponse.data
					)
				return .error(
					.xrpcError(status: status, error: errorObject)
				)
			default:
				break
			}

			return .error(.unrecognized(fullResponse.response))
		} catch {
			return .error(.undecodable(fullResponse.response, underlying: error))
		}
	}

	private static func parseSuccess(body: Data) throws -> Output {
		switch Output.self {
		case is Data.Type:
			return try (body as? Output).tryUnwrap
		case is Data?.Type:
			let result = body.isEmpty ? nil : body
			return try (result as? Output).tryUnwrap
		default:
			return try JSONDecoder.atproto
				.decode(Output.self, from: body)
		}
	}
}

//functional handling
extension HTTPDataResponse {
	public func parse<X: Atproto.XRPC.ResponseParsing>(_ xrpc: X.Type) throws -> X.Output {
		try X.parse(fullResponse: self).output
	}
}
