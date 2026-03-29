//
//  XRPCOutput.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 3/29/26.
//

import Foundation
import GermConvenience
import HTTPTypes

public protocol XRPCResponseParsing: Sendable {
	associatedtype Output: Decodable, Mockable, Sendable
	//this is defined in the lexicon, and additionally in the api spec
	static var badRequestErrors: Set<String> { get }
	static var recognizedStatuses: Set<HTTPResponse.Status> { get }
}

//default
extension XRPCResponseParsing {
	static public var recognizedStatuses: Set<HTTPResponse.Status> {
		[.badRequest, .unauthorized]
	}

	static public var defaultErrors: Set<String> {
		["InvalidRequest", "ExpiredToken", "InvalidToken"]
	}
}

public enum ParsedXRPCResponse<Output: Decodable> {
	case ok(Output)
	case error(status: HTTPResponse.Status, error: Lexicon.XRPCError)
	case unrecognized(HTTPResponse)
}

extension XRPCResponseParsing {
	public static func parse(
		fullResponse: HTTPDataResponse
	) throws -> ParsedXRPCResponse<Output> {
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
					return .error(status: .badRequest, error: errorObject)
				}
			case let status where Self.recognizedStatuses.contains(status):
				let errorObject = try JSONDecoder()
					.decode(
						Lexicon.XRPCError.self,
						from: fullResponse.data
					)
				return .error(status: status, error: errorObject)
			default:
				break
			}

			return .unrecognized(fullResponse.response)
		} catch {
			return .unrecognized(fullResponse.response)
		}
	}
}
