//
//  Secp256k1TestSigner.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypesVerifyMocks
import Foundation
import P256K

///Wraps `P256K.Signing.PrivateKey` to feed `RepoFixture.commit(signedBy:)` a
///real k256 signature. Lives here, not in `AtprotoTypesVerifyMocks`: P256K is
///a differential-test dependency only, and `AtprotoTypesVerify`'s own
///secp256k1 is deliberately verify-only with no signing path, so nothing
///outside this test target should ever construct a k256 private key.
struct Secp256k1TestSigner: RepoFixtureSigningKey {
	let key: P256K.Signing.PrivateKey

	init() {
		key = try! P256K.Signing.PrivateKey()
	}

	var publicKey: Secp256k1PublicKey {
		Secp256k1PublicKey(compressedRepresentation: key.publicKey.dataRepresentation)
	}

	///P256K normalises every signature it produces to low-S
	///(BIP-146/`secp256k1_ecdsa_sign`), same as swift-crypto's P256 does not —
	///so, unlike the P256 conformance, this needs no extra fold.
	func repoFixtureSignature(for message: Data) throws -> Data {
		key.signature(for: message).compactRepresentation
	}
}
