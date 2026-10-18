//
//  PLCDocumentRenderer.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 10/18/26.
//

import AtprotoTypes
import BaseX
import Foundation

extension Atproto.PLC {
	///Renders the DID document an operation implies.
	///
	///The method specification presents a document by example and leaves the
	///details there; the directory is the thing that actually serves one, and a
	///device checking a served log is checking that it would have produced the
	///same document. So this follows the directory: a full `did:plc:…#atproto`
	///verification-method id rather than the example's bare fragment, and a
	///third `@context` entry naming the curve of the keys actually present —
	///`secp256k1-2019` or `ecdsa-2019`, omitted entirely when there are no
	///verification methods to describe.
	enum DocumentRenderer {
		private static let baseContext = [
			"https://www.w3.org/ns/did/v1",
			"https://w3id.org/security/multikey/v1",
		]

		///The document for an active DID, from the last live operation.
		static func render(did: Atproto.DID, operation: Operation) throws
			-> Atproto.DIDDocument
		{
			var context = baseContext
			var verificationMethods: [Atproto.DIDDocument.VerificationMethod] = []
			for method in operation.verificationMethods {
				if let suite = contextSuite(ofDidKey: method.value),
					!context.contains(suite)
				{
					context.append(suite)
				}
				verificationMethods.append(
					Atproto.DIDDocument.VerificationMethod(
						id: "\(did.rawValue)#\(method.key)",
						type: "Multikey",
						controller: did.rawValue,
						publicKeyMultibase: withoutDidKeyPrefix(
							method.value)
					)
				)
			}

			return Atproto.DIDDocument(
				context: context,
				id: did.rawValue,
				alsoKnownAs: operation.alsoKnownAs,
				verificationMethod: verificationMethods,
				service: operation.services.map {
					Atproto.DIDDocument.Service(
						id: "#\($0.key)",
						type: $0.value.type,
						serviceEndpoint: URL(string: $0.value.endpoint)
					)
				}
			)
		}

		///The document for a deactivated DID: a `plc_tombstone` clears every
		///data field, so the document keeps its id and nothing else.
		static func renderTombstone(did: Atproto.DID) throws -> Atproto.DIDDocument {
			Atproto.DIDDocument(
				context: baseContext,
				id: did.rawValue,
				alsoKnownAs: [],
				verificationMethod: [],
				service: []
			)
		}

		///The `@context` entry a verification-method key calls for, or `nil` for
		///a key whose curve has no suite.
		///
		///The key is sniffed at the multicodec rather than parsed into a
		///`RepoSigningKey`, which would refuse anything but secp256k1 and P-256:
		///the method specification lets a verification-method key be any
		///syntactically valid `did:key`, so a key the renderer cannot name a
		///suite for is still published — it simply contributes no context entry.
		private static func contextSuite(ofDidKey key: String) -> String? {
			guard let curve = curve(ofDidKey: key) else { return nil }
			switch curve {
			case .p256: return "https://w3id.org/security/suites/ecdsa-2019/v1"
			case .secp256k1:
				return "https://w3id.org/security/suites/secp256k1-2019/v1"
			}
		}

		private static func curve(ofDidKey key: String) -> RepoSigningKey.Curve? {
			guard key.hasPrefix("did:key:") else { return nil }
			let multibase = key.dropFirst("did:key:".count)
			guard multibase.hasPrefix("z") else { return nil }
			guard
				let decoded = try? BaseX.decode(
					String(multibase.dropFirst()), as: .base58BTC)
			else {
				return nil
			}

			var reader = ByteReader(decoded)
			guard let codec = try? reader.readUnsignedVarint() else { return nil }
			return RepoSigningKey.Curve.named(codec)
		}

		private static func withoutDidKeyPrefix(_ key: String) -> String {
			key.hasPrefix("did:key:")
				? String(key.dropFirst("did:key:".count))
				: key
		}
	}
}
