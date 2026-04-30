//
//  ErrorResponse.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 2/26/26.
//

extension Atproto.XRPC {
	public struct ErrorResponse: Sendable, Codable {
		public let error: String
		public let message: String

		public init(error: String, message: String) {
			self.error = error
			self.message = message
		}
	}
}
