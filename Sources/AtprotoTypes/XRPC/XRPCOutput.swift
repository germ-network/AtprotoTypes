//
//  XRPCOutput.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 3/29/26.
//

import Foundation
import GermConvenience
import HTTPTypes

extension Atproto.XRPC {
	public protocol ResponseParsing: Sendable {
		associatedtype Output: Decodable, Sendable
		//this is defined in the lexicon, and additionally in the api spec
		static var badRequestErrors: Set<String> { get }
		static var recognizedStatuses: Set<HTTPResponse.Status> { get }
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
		case error(ParseXRPCError)

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

public enum ParseXRPCError: LocalizedError {
	case xrpcError(status: HTTPResponse.Status, error: Lexicon.XRPCError)
	case unrecognized(HTTPResponse)

	public var errorDescription: String? {
		switch self {
		case .xrpcError(let status, let error):
			"\(status): \(error.error)"
		case .unrecognized(let response):
			"Unrecognized response: \(response)"
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
				return .ok(
					try JSONDecoder()
						.decode(
							Output.self, from: fullResponse.data
						)
				)
			case .badRequest:
				let errorObject = try JSONDecoder()
					.decode(
						Lexicon.XRPCError.self,
						from: fullResponse.data
					)
				if Self.badRequestErrors.contains(errorObject.error) {
					return .error(
						.xrpcError(status: .badRequest, error: errorObject)
					)
				}
			case let status where Self.recognizedStatuses.contains(status):
				let errorObject = try JSONDecoder()
					.decode(
						Lexicon.XRPCError.self,
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
			return .error(.unrecognized(fullResponse.response))
		}
	}
}

//functional handling
extension HTTPDataResponse {
	public func parse<X: Atproto.XRPC.ResponseParsing>(_ xrpc: X.Type) throws -> X.Output {
		try X.parse(fullResponse: self).output
	}
}
