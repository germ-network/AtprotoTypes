//
//  DIDDocument+Verified.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/30/26.
//

import Foundation

extension Atproto.DIDDocument {
	public struct Verified {
		public let document: Atproto.DIDDocument
		//which may be reserved value "handle.invalid"
		public let did: Atproto.DID
		public let verifiedHandle: Atproto.Handle

		public func check(expectedDid: Atproto.DID) throws -> Self {
			guard did == expectedDid else {
				throw ResolverErrors.didMismatch
			}
			return self
		}

		enum ResolverErrors: LocalizedError {
			case didMismatch

			var errorDescription: String? {
				switch self {
				case .didMismatch: "did did not match"
				}
			}
		}
	}

	public func verified(
		resolver: (Atproto.Handle) async throws -> Atproto.DID
	) async throws -> Verified {
		let did = try Atproto.DID(string: id)

		guard let unverifiedHandle else {
			return .init(document: self, did: did, verifiedHandle: .invalid)
		}

		let resolvedDid = try await resolver(unverifiedHandle)

		guard resolvedDid == did else {
			return .init(document: self, did: did, verifiedHandle: .invalid)
		}

		return .init(document: self, did: did, verifiedHandle: unverifiedHandle)
	}

	///Synchronous version of the above if we just resolved handle to did
	public func verified(
		expecting: Atproto.Handle
	) throws -> Verified {
		let did = try Atproto.DID(string: id)

		guard let unverifiedHandle else {
			return .init(document: self, did: did, verifiedHandle: .invalid)
		}

		guard expecting == unverifiedHandle else {
			return .init(document: self, did: did, verifiedHandle: .invalid)
		}

		return .init(document: self, did: did, verifiedHandle: unverifiedHandle)
	}

	//the value we parse still needs to be resolved back to the same
	//did to verify it
	private var unverifiedHandle: Atproto.Handle? {
		(alsoKnownAs ?? []).compactMap {
			// Valid AT URI
			if let atURI = Atproto.ATURI(rawValue: $0) {
				// AT URI for an authority, not a record or collection
				if atURI.collection == nil, atURI.recordKey == nil {
					// AT URI for a handle, not a DID
					if case .handle(let handle) = atURI.authority {
						return handle
					}
				}
			}
			return nil
		}
		.first
	}
}
