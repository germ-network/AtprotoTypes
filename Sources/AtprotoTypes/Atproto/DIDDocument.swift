//
//  DIDDocument.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 2/18/26.
//  Derived from the type in AtprotoKit by CJ Riley
//

import Foundation

/// Represents a DID document in the AT Protocol, containing crucial information fo
/// AT Protocol functionality.
///
/// The DID document includes the decentralized identifier (DID), verification methods, and
/// service endpoints necessary for interacting with the AT Protocol ecosystem, such as
/// authentication and data storage locations.
extension Atproto {
	public struct DIDDocument: Sendable, Codable, Equatable {

		/// An array of context URLs for the DID document, providing additional semantics for
		/// the properties. Optional per the canonical schema, and a bare string is accepted
		/// in addition to an array — the canonical schema restricts the bare-string form to
		/// exactly `https://www.w3.org/ns/did/v1`; this type is more permissive since nothing
		/// here interprets `@context` semantically.
		public let context: [String]?

		/// The unique identifier of the DID document.
		public let id: String

		/// An array of URIs under which this decentralized identifier (DID) is also known, including
		/// the primary handle URI. Optional.
		public let alsoKnownAs: [String]?

		/// An array of methods for verifying digital signatures, including the public signing key
		/// for the account. Optional per the canonical schema.
		public let verificationMethod: [VerificationMethod]?

		/// An array of service endpoints related to the decentralized identifier (DID), including the
		/// Personal Data Server's (PDS) location. Optional per the canonical schema.
		public let service: [Service]?

		/// Checks if the ``service`` property array contains items, and if so, sees if `#atproto_pds`
		/// is in the ``ATService/id`` property.
		///
		/// - Returns: An ``ATService`` item.
		///
		/// - Throws: ``DIDDocumentError`` if ``service`` is empty, if none of the items
		/// contain `#atproto_pds`, or if that item's endpoint fails
		/// ``Service/validate(endpoint:policy:)`` or didn't decode to a usable `URL`.
		public func checkServiceForAtproto(
			policy: EndpointPolicy = .default
		) throws -> Service {
			let services = self.service ?? []

			guard services.count > 0 else {
				throw Errors.emptyArray
			}

			for service in services {
				if service.id == "#atproto_pds" {
					guard let endpoint = service.serviceEndpoint else {
						// The first matching entry is authoritative
						// (https://atproto.com/specs/did#did-documents: "the
						// first matching entry... should be used, and any
						// others ignored") — an unusable endpoint here is not
						// a reason to keep searching for a second match.
						throw Errors.missingServiceUrl
					}
					try Service.validate(endpoint: endpoint, policy: policy)
					return service
				}
			}

			throw Errors.noAtprotoPDSValue
		}

		enum CodingKeys: String, CodingKey {
			case context = "@context"
			case id
			case alsoKnownAs
			case verificationMethod
			case service
		}

		/// `@context` accepts a bare string in addition to the usual array —
		/// see the property's own doc comment. Everything else decodes as
		/// `decodeIfPresent`, since the canonical schema makes all of it but
		/// `id` optional.
		///
		/// A `@context` that's neither an array nor a string (a number,
		/// `null`, an array of non-strings) also decodes to `nil` rather than
		/// throwing — deliberately lenient, since nothing here reads
		/// `@context` and a hand-authored did:web document is exactly where a
		/// malformed-but-harmless context value is most likely to show up.
		/// `id` has no such leniency: it stays a plain `try`, so a missing or
		/// wrongly-typed `id` still fails the whole decode.
		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			if let contextArray = try? container.decodeIfPresent(
				[String].self, forKey: .context)
			{
				context = contextArray
			} else if let contextString = try? container.decode(
				String.self, forKey: .context)
			{
				context = [contextString]
			} else {
				context = nil
			}
			id = try container.decode(String.self, forKey: .id)
			alsoKnownAs = try container.decodeIfPresent(
				[String].self, forKey: .alsoKnownAs)
			verificationMethod = try container.decodeIfPresent(
				[VerificationMethod].self, forKey: .verificationMethod)
			service = try container.decodeIfPresent(
				[Service].self, forKey: .service)
		}

		/// Errors relating to the DID Document.
		public enum Errors: Error, Equatable {

			/// The ``DIDDocument/service`` array is empty.
			case emptyArray

			/// None of the items in the ``DIDDocument/service`` array contains a `#atproto_pds`
			/// value in the ``ATService/id`` property.
			case noAtprotoPDSValue

			case urlConstructionError
			case missingServiceUrl

			/// The service endpoint is not `https`.
			case insecureServiceUrlScheme(String?)

			/// The service endpoint's host is one we refuse to send traffic to,
			/// such as a loopback, link-local, or private-range address.
			case disallowedServiceUrlHost(String)

			/// `verified(expecting:did:)` / `verified(expectedDid:resolver:)` —
			/// the document's own `id` does not match the DID it was resolved
			/// for.
			case documentIdMismatch(requested: String, returned: String)
		}

		public init(
			context: [String]? = nil,
			id: String,
			alsoKnownAs: [String]?,
			verificationMethod: [VerificationMethod]? = nil,
			service: [Service]? = nil
		) {
			self.context = context
			self.id = id
			self.alsoKnownAs = alsoKnownAs
			self.verificationMethod = verificationMethod
			self.service = service
		}
	}
}

extension Atproto.DIDDocument {
	/// Describes a method for verifying digital signatures in the AT Protocol, including the public
	/// signing key.
	public struct VerificationMethod: Sendable, Codable, Equatable {

		/// The unique identifier of the verification method.
		public let id: String

		/// The type of verification method that indicates the cryptographic curve used.
		public let type: String

		/// The controller of the verification method, which matches the
		/// decentralized identifier (DID).
		public let controller: String

		/// The public key, in multibase encoding; used for verifying digital signatures.
		/// Optional per the canonical schema — a `publicKeyJwk`-only method is legal,
		/// though this type does not model that field, since nothing here reads it.
		public let publicKeyMultibase: String?

		package init(
			id: String,
			type: String,
			controller: String,
			publicKeyMultibase: String?
		) {
			self.id = id
			self.type = type
			self.controller = controller
			self.publicKeyMultibase = publicKeyMultibase
		}
	}

	/// Represents a service endpoint in a DID document, such as the
	/// Personal Data Server's (PDS) location.
	public struct Service: Sendable, Codable, Equatable {

		/// The unique identifier of the service.
		public let id: String

		/// The type of service (matching `AtprotoPersonalDataServer`) for use in identifying
		/// the Personal Data Server (PDS).
		public let type: String

		/// The endpoint URL for the service, specifying the location of the service.
		/// The canonical schema permits an object shape here too — this type never
		/// stores one, since nothing here (or upstream, in `@atproto/identity`)
		/// treats an object-shaped endpoint as usable. `nil` covers that case and
		/// anything else `serviceEndpoint` legally isn't (absent, a number,
		/// `null`) — `URL(string:)` itself is too lenient to reject most garbage
		/// strings, so the real screen for an unusable-but-URL-shaped value is
		/// `Service.validate`, not this initializer. Either way a malformed
		/// entry decodes with a `nil` endpoint rather than failing the whole
		/// document.
		public let serviceEndpoint: URL?

		enum CodingKeys: String, CodingKey {
			case id, type, serviceEndpoint
		}

		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			id = try container.decode(String.self, forKey: .id)
			type = try container.decode(String.self, forKey: .type)
			if let endpointString = try? container.decode(
				String.self, forKey: .serviceEndpoint)
			{
				serviceEndpoint = URL(string: endpointString)
			} else {
				serviceEndpoint = nil
			}
		}

		public init(id: String, type: String, serviceEndpoint: URL?) {
			self.id = id
			self.type = type
			self.serviceEndpoint = serviceEndpoint
		}
	}
}

extension Atproto.DIDDocument {
	//https://atproto.com/specs/did#did-documents
	//"The first matching entry in the array should be used, and any others ignored. "
	//"an account with no valid PDS location in their DID document is broken"
	public var pdsUrl: URL {
		get throws { try pdsUrl(policy: .default) }
	}

	///a property can't take an argument, so anything but ``EndpointPolicy/default``
	///goes through this spelling
	public func pdsUrl(policy: EndpointPolicy) throws -> URL {
		guard
			let service = (service ?? []).first(where: {
				$0.type == "AtprotoPersonalDataServer"
			})
		else {
			throw Errors.missingServiceUrl
		}
		guard let endpoint = service.serviceEndpoint else {
			throw Errors.missingServiceUrl
		}
		try Service.validate(endpoint: endpoint, policy: policy)
		return endpoint
	}
}
