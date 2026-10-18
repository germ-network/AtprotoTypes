//
//  PLCTestSupport.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 10/18/26.
//

import AtprotoTypes
import AtprotoTypesVerify
import AtprotoTypesVerifyMocks
import Crypto
import Foundation

extension Atproto.PLC.VerifyError {
	///The case's name, so a test can assert which rejection happened without
	///predicting a diagnostic payload it has no business knowing.
	var caseName: String {
		String(describing: self).prefix(while: { $0 != "(" }).description
	}
}

///Matches a thrown error to one `VerifyError` case by name.
func isCase(_ name: String) -> (any Error) -> Bool {
	{ ($0 as? Atproto.PLC.VerifyError)?.caseName == name }
}

///One key, one service, built rather than captured, so a test can change
///exactly one field and watch the verifier refuse for that reason rather than
///for whatever a captured blob happens to contain.
struct PLCScenario {
	let signer = P256.Signing.PrivateKey()

	var rotationKey: String { PLCFixture.didKey(signer.publicKey) }

	var services: [(key: String, value: PLCFixture.Service)] {
		[
			(
				key: "atproto_pds",
				value: PLCFixture.Service(
					type: "AtprotoPersonalDataServer",
					endpoint: "https://example.test"
				)
			)
		]
	}

	func unsigned(rotationKeys: [String]? = nil, prev: Atproto.CID?) -> DAGCBORValue {
		PLCFixture.unsignedOperation(
			rotationKeys: rotationKeys ?? [rotationKey],
			verificationMethods: [(key: "atproto", value: rotationKey)],
			alsoKnownAs: ["at://example.test"],
			services: services,
			prev: prev
		)
	}

	func signed(rotationKeys: [String]? = nil, prev: Atproto.CID?) throws -> DAGCBORValue {
		try PLCFixture.signed(
			unsigned(rotationKeys: rotationKeys, prev: prev), with: signer)
	}
}
