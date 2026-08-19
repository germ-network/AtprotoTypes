//
//  Secp256k1ECDSADifferentialTests.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 8/17/26.
//

import Crypto
import Foundation
import P256K
import Testing

@testable import AtprotoTypesVerify

///P256K — a real, C-backed secp256k1 implementation — is the oracle here.
///`Secp256k1.ECDSA` is a from-scratch, verify-only Swift port (see that file's
///header for why), and its own unit tests only pin known-answer values; this
///suite is what checks it against an independent implementation across many
///keypairs, messages, and deliberately mutated inputs.
///
///Both sides always work from the raw message, never a shared "digest"
///value: P256K's own `Digest` protocol is a different type from swift-crypto's
///(both named `SHA256`, imported into this file at once — `P256K.signature
///(for:)`'s `Digest`-typed overload can't accept a `Crypto.SHA256.Digest`),
///so this uses each library's own message-hashing overload instead of trying
///to share one digest value across both.
@Suite("secp256k1 ECDSA differential against P256K")
struct Secp256k1ECDSADifferentialTests {
	static let messages: [Data] = [
		Data(),
		Data("atproto commit signature".utf8),
		Data(repeating: 0xFF, count: 300),
	]

	@Test("a genuine signature is accepted by both verifiers", arguments: 0..<100)
	func agreesOnGenuineSignatures(_ index: Int) throws {
		let key = try P256K.Signing.PrivateKey()
		let publicKeyBytes = key.publicKey.dataRepresentation

		for message in Self.messages {
			let signature = key.signature(for: message).compactRepresentation

			let oracleAccepts = key.publicKey.isValidSignature(
				try P256K.Signing.ECDSASignature(compactRepresentation: signature),
				for: message)
			#expect(oracleAccepts)  //sanity: P256K agrees with itself

			let digest = Crypto.SHA256.hash(data: message)
			let oursAccepts = Secp256k1.ECDSA.verify(
				signature: signature, digest: Data(digest),
				compressedPublicKey: publicKeyBytes)
			#expect(oursAccepts)
		}
	}

	///One bit flipped in `r`, `s`, the message, or the public key, each
	///checked independently against the same genuine signature. A flip can
	///occasionally still parse as a valid-but-different signature component or
	///point — the assertion is not "fails to parse", it's "both verifiers
	///refuse", which holds either way.
	@Test(
		"flipping a bit in r, s, the message, or the key is refused by both",
		arguments: 0..<20
	)
	func agreesOnMutatedSignatures(_ index: Int) throws {
		let key = try P256K.Signing.PrivateKey()
		let publicKeyBytes = key.publicKey.dataRepresentation
		let message = Data("mutate me \(index)".utf8)
		let signature = key.signature(for: message).compactRepresentation

		func flip(_ data: Data, at position: Int) -> Data {
			var copy = data
			let byteIndex = copy.index(copy.startIndex, offsetBy: position)
			copy[byteIndex] ^= 0x01
			return copy
		}

		let cases: [(signature: Data, message: Data, key: Data)] = [
			(flip(signature, at: 0), message, publicKeyBytes),  //mutate r
			(flip(signature, at: 32), message, publicKeyBytes),  //mutate s
			(signature, flip(message, at: 0), publicKeyBytes),  //mutate the message
			(signature, message, flip(publicKeyBytes, at: 1)),  //mutate the key
		]

		for testCase in cases {
			let digest = Crypto.SHA256.hash(data: testCase.message)
			let oursAccepts = Secp256k1.ECDSA.verify(
				signature: testCase.signature,
				digest: Data(digest),
				compressedPublicKey: testCase.key)
			#expect(!oursAccepts)

			let oracleAccepts: Bool =
				if let parsedSignature = try? P256K.Signing.ECDSASignature(
					compactRepresentation: testCase.signature),
					let parsedKey = try? P256K.Signing.PublicKey(
						dataRepresentation: testCase.key,
						format: .compressed)
				{
					parsedKey.isValidSignature(
						parsedSignature, for: testCase.message)
				} else {
					false
				}
			#expect(!oracleAccepts)
		}
	}
}
