//
//  DIDDocument+Verified.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/30/26.
//

import Foundation

extension Atproto.DIDDocument {
	public struct Verified: Sendable {
		public let document: Atproto.DIDDocument
		public let did: Atproto.DID
		//which may be reserved value "handle.invalid"
		public let verifiedHandle: Atproto.Handle

		package init(
			document: Atproto.DIDDocument,
			did: Atproto.DID,
			verifiedHandle: Atproto.Handle
		) {
			self.document = document
			self.did = did
			self.verifiedHandle = verifiedHandle
		}
	}

	/// `expectedDid`, when supplied, is compared against the document's own
	/// `id` and throws on mismatch — the same check the synchronous overload
	/// below always performs. A handle mismatch instead degrades to
	/// `verifiedHandle: .invalid`; the two are not symmetric on purpose, since
	/// a DID mismatch means the document does not belong to the identity this
	/// call resolved, while a handle mismatch just means that handle isn't
	/// (yet) verified.
	public func verified(
		expectedDid: Atproto.DID? = nil,
		resolver: (Atproto.Handle) async throws -> Atproto.DID
	) async throws -> Verified {
		let did = try Atproto.DID(string: id)
		if let expectedDid {
			guard did == expectedDid else {
				throw Errors.documentIdMismatch(
					requested: expectedDid.rawValue, returned: id)
			}
		}

		guard let unverifiedHandle else {
			return .init(document: self, did: did, verifiedHandle: .invalid)
		}

		let resolvedDid = try await resolver(unverifiedHandle)

		guard resolvedDid == did else {
			return .init(document: self, did: did, verifiedHandle: .invalid)
		}

		return .init(document: self, did: did, verifiedHandle: unverifiedHandle)
	}

	///Synchronous version of the above if we just resolved handle to did.
	///Always throws on a DID mismatch — see the async overload's doc comment
	///on why that's asymmetric with the handle check just below it.
	public func verified(
		expecting: Atproto.Handle,
		did: Atproto.DID
	) throws -> Verified {
		let documentDid = try Atproto.DID(string: id)
		guard documentDid == did else {
			throw Errors.documentIdMismatch(requested: did.rawValue, returned: id)
		}

		guard let unverifiedHandle else {
			return .init(document: self, did: documentDid, verifiedHandle: .invalid)
		}

		guard expecting == unverifiedHandle else {
			return .init(document: self, did: documentDid, verifiedHandle: .invalid)
		}

		return .init(document: self, did: documentDid, verifiedHandle: unverifiedHandle)
	}

	//the value we parse still needs to be resolved back to the same
	//did to verify it
	package var unverifiedHandle: Atproto.Handle? {
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
