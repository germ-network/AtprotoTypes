//
//  XRPCError.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 2/26/26.
//

extension Lexicon {
	public struct XRPCError: Sendable, Codable {
		public let error: String
		public let message: String

		public init(error: String, message: String) {
			self.error = error
			self.message = message
		}
	}
}
