//
//  XRPCOutput.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 3/29/26.
//

import Foundation
import GermConvenience
import HTTPTypes

//Allow for specific decoding of xrpc calls
protocol XRPCResponse {
	associatedtype Output: Decodable

	static func parse(
		fullResponse: HTTPDataResponse
	) throws -> ParsedXRPCResponse<Output>
}

enum ParsedXRPCResponse<Output: Decodable> {
	case ok(Output)
	case error(status: HTTPResponse.Status, error: Lexicon.XRPCError)
	case unrecognized(HTTPResponse)
}
