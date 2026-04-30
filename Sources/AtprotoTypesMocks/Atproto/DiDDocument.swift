//
//  DiDDocument.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 4/29/26.
//

import AtprotoTypes
import Foundation
import Mockable

extension Atproto.DIDDocument: Mockable {
	public static func mock() throws -> Self {
		guard let serviceEndpoint = URL(string: "https://blusher.us-east.host.bsky.network")
		else {
			throw Errors.urlConstructionError
		}
		return .init(
			context: [
				"https://www.w3.org/ns/did/v1",
				"https://w3id.org/security/multikey/v1",
				"https://w3id.org/security/suites/secp256k1-2019/v1",
			],
			id: "did:plc:4yvwfwxfz5sney4twepuzdu7",
			alsoKnownAs: ["at://example.com"],
			verificationMethod: [
				.init(
					id: "did:plc:4yvwfwxfz5sney4twepuzdu7#atproto",
					type: "Multikey",
					controller: "did:plc:4yvwfwxfz5sney4twepuzdu7",
					publicKeyMultibase:
						"zQ3shPrWRUXva2mWziWZt1vrjuXUx3E28WfgsAwStMcAmDt93"
				)
			],
			service: [
				.init(
					id: "#atproto_pds",
					type: "AtprotoPersonalDataServer",
					serviceEndpoint: serviceEndpoint
				)
			]
		)
	}
}
