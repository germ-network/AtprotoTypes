//
//  DID.swift
//  SwiftAtprotoOAuth
//
//  Created by Mark @ Germ on 4/22/25.
//

import Foundation

//https://atproto.com/specs/did
//2KB limit, case sensitive,
//https://www.w3.org/TR/did-1.0/#did-syntax

//Store it as a string, do some rudimentary checking
//can implement more checks later

extension Atproto {
	public struct DID: RawRepresentable, Codable, Hashable, Sendable {
		enum Constants {
			static let prefix = "did:"
		}

		public let identifier: String
		public let method: Methods

		public var rawValue: String {
			Constants.prefix + method.rawValue + ":" + identifier
		}

		public init?(rawValue: String) {
			guard rawValue.hasPrefix(Constants.prefix) else {
				return nil
			}
			let remainder = rawValue.dropFirst(Constants.prefix.count)
			do {
				(method, identifier) = try Methods.parse(remainder)
			} catch {
				return nil
			}
		}

		public enum Methods: String, CaseIterable, Sendable {
			case plc
			case web

			static func parse(
				_ subsequence: String.SubSequence
			) throws -> (Self, String) {
				for method in Methods.allCases {
					if subsequence.hasPrefix(method.rawValue + ":") {
						return (
							method,
							String(
								subsequence.dropFirst(
									method.rawValue.count + 1)
							)
						)
					}
				}
				throw Atproto.DID.Errors.invalidMethod
			}
		}

		public init(method: Methods, identifier: String) {
			self.method = method
			self.identifier = identifier
		}
	}
}

extension Atproto.DID {
	public enum Errors: Error {
		case invalidPrefix
		case invalidMethod
	}
}

extension Atproto.DID.Errors: LocalizedError {
	public var errorDescription: String? {
		switch self {
		case .invalidPrefix: "Invalid prefix"
		case .invalidMethod: "Invalid method"
		}
	}
}
