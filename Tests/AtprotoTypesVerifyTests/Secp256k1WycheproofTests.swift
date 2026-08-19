//
//  Secp256k1WycheproofTests.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import AtprotoTypesVerify
import AtprotoTypesVerifyMocks
import Foundation
import Testing

///Google/C2SP's Wycheproof project publishes adversarially-constructed ECDSA
///test vectors — edge cases in the modular arithmetic (near-order scalars,
///point duplication, small r/s) that a from-scratch implementation's own
///hand-picked known-answer tests are unlikely to stumble onto by chance.
///
///`ecdsa_secp256k1_sha256_p1363_test.json`, vendored below under Apache-2.0
///from https://github.com/C2SP/wycheproof (LICENSE copied alongside it in
///`Resources/wycheproof/`) — 252 vectors over 108 groups, IEEE P1363
///(fixed-width `r ‖ s`) over SHA-256, secp256k1.
private struct WycheproofFile: Decodable {
	let numberOfTests: Int
	let testGroups: [TestGroup]

	struct TestGroup: Decodable {
		let publicKey: PublicKey
		let sha: String
		let tests: [Vector]
	}

	struct PublicKey: Decodable {
		let curve: String
		///`0x04 ‖ x ‖ y`, SEC1 uncompressed, hex.
		let uncompressed: String
	}

	struct Vector: Decodable {
		let tcId: Int
		let comment: String
		///Hex-encoded raw message — the vectors are pre-hash, so this file
		///hashes it with SHA-256 itself rather than passing a digest.
		let msg: String
		///Hex-encoded `r ‖ s`, fixed-width when well-formed; several vectors
		///deliberately vary the length to probe truncated/padded encodings.
		let sig: String
		///"valid" or "invalid" — Wycheproof's own verdict, which this suite
		///reclassifies through atproto's stricter low-S policy before
		///comparing against what the verifier actually does.
		let result: String
	}
}

@Suite("secp256k1 against Wycheproof test vectors")
struct Secp256k1WycheproofTests {
	enum Bucket: Equatable {
		case accepted
		case refusedHighS
		case refusedBadLength
		case refusedOther
	}

	///`RepoSigningKey.verify` checks low-S on the raw signature bytes before
	///it ever parses `r`/`s` as scalars — mirroring the pre-existing p256
	///branch exactly, deliberately, for one shared check instead of a
	///per-curve variant. A consequence: a vector whose `s` is not even in
	///canonical range (`s >= n`, e.g. Wycheproof's `s = p` cases) still has
	///`s > n/2` as raw bytes, so it is classified non-canonical rather than
	///reaching the "other invalid" path — it is refused either way, this only
	///picks which specific `ProofError` case reports it, so the census
	///predicts that reclassification rather than the parse-first ordering a
	///from-scratch design might otherwise choose.
	static func expectedBucket(signature: Data, result: String) -> Bucket {
		guard signature.count == 64 else { return .refusedBadLength }
		let s = Array(signature.suffix(32))
		guard RepoSigningKey.isLowS(s, order: RepoSigningKey.secp256k1Order) else {
			return .refusedHighS
		}
		return result == "valid" ? .accepted : .refusedOther
	}

	static func signingKey(uncompressedHex: String) throws -> RepoSigningKey {
		let bytes = try data(hex: uncompressedHex)
		precondition(
			bytes.count == 65 && bytes.first == 0x04, "not a SEC1 uncompressed point")
		let x = bytes.subdata(
			in: bytes.index(
				bytes.startIndex, offsetBy: 1)..<bytes.index(
					bytes.startIndex, offsetBy: 33))
		let y = bytes.subdata(
			in: bytes.index(
				bytes.startIndex, offsetBy: 33)..<bytes.index(
					bytes.startIndex, offsetBy: 65))
		let prefix: UInt8 = (y.last! & 1 == 0) ? 0x02 : 0x03
		let publicKey = Secp256k1PublicKey(compressedRepresentation: Data([prefix]) + x)
		return try RepoSigningKey(multibase: RepoFixture.multibase(publicKey))
	}

	static func data(hex: String) throws -> Data {
		var bytes = [UInt8]()
		bytes.reserveCapacity(hex.count / 2)
		var index = hex.startIndex
		while index < hex.endIndex {
			let next = hex.index(index, offsetBy: 2)
			bytes.append(try #require(UInt8(hex[index..<next], radix: 16)))
			index = next
		}
		return Data(bytes)
	}

	///The census is the point: not "no crash", but the exact, independently
	///verified partition of all 252 vectors — 95 accepted, 116 refused for
	///being non-canonical (raw `s > n/2`, whether or not `s` was even a valid
	///scalar), 18 refused for a non-64-byte encoding, 23 refused for every
	///other reason. A silent shift in any bucket means the verifier's
	///behavior changed on a real edge case.
	@Test("every vector lands in the bucket its own encoding predicts")
	func matchesExactCensus() throws {
		let url = try #require(
			Bundle.module.url(
				forResource: "ecdsa_secp256k1_sha256_p1363_test",
				withExtension: "json",
				subdirectory: "wycheproof"))
		let file = try JSONDecoder().decode(
			WycheproofFile.self, from: Data(contentsOf: url))
		#expect(file.numberOfTests == 252)

		var tally: [Bucket: Int] = [:]

		for group in file.testGroups {
			#expect(group.publicKey.curve == "secp256k1")
			#expect(group.sha == "SHA-256")
			let signingKey = try Self.signingKey(
				uncompressedHex: group.publicKey.uncompressed)

			for vector in group.tests {
				let message = try Self.data(hex: vector.msg)
				let signature = try Self.data(hex: vector.sig)
				let expected = Self.expectedBucket(
					signature: signature, result: vector.result)

				let actual: Bucket
				do {
					try signingKey.verify(signature: signature, over: message)
					actual = .accepted
				} catch Atproto.Repo.ProofError.badSignatureLength {
					actual = .refusedBadLength
				} catch Atproto.Repo.ProofError.nonCanonicalSignature {
					actual = .refusedHighS
				} catch Atproto.Repo.ProofError.signatureDidNotVerify {
					actual = .refusedOther
				}

				#expect(
					actual == expected, "tcId \(vector.tcId): \(vector.comment)"
				)
				tally[actual, default: 0] += 1
			}
		}

		#expect(tally[.accepted] == 95)
		#expect(tally[.refusedHighS] == 116)
		#expect(tally[.refusedBadLength] == 18)
		#expect(tally[.refusedOther] == 23)
	}
}
