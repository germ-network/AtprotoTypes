//
//  ECDSA.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 8/17/26.
//

import Foundation

///Verify-only ECDSA over secp256k1. Deliberately just the math: low-S is an
///atproto policy, not an ECDSA property (a high-S signature is a
///mathematically valid twin of its low-S counterpart), so that rejection
///stays a caller concern — `RepoSigningKey.verify` enforces it the same way
///for both curves, rather than this file half-owning the policy.
extension Secp256k1 {
	enum ECDSA {
		///`signature` is 64 bytes, big-endian `r ‖ s`. `digest` is the message
		///hash (SHA-256, per the repo signing format) — this does not hash the
		///message itself. Returns `false` for any malformed component: a zero
		///or out-of-range `r`/`s`, an undecodable public key, or a recovered
		///point at infinity all collapse to a plain refusal rather than a
		///distinguished error, matching how Wycheproof's "other invalid"
		///bucket expects these to be indistinguishable from a wrong signature.
		static func verify(signature: Data, digest: Data, compressedPublicKey: Data) -> Bool
		{
			//not reachable from `RepoSigningKey.verify` today (always a
			//32-byte SHA-256 output) — guarded anyway, because
			//`Scalar(reducingBigEndian:)` folds any other length to zero,
			//and z = 0 lets anyone forge a signature over an infinite
			//family of (r, s) pairs without the private key at all: pick
			//any t, R = t·G, r = R.x mod n, s = r·t⁻¹ mod n.
			guard digest.count == 32 else { return false }
			guard signature.count == 64 else { return false }
			guard let r = Scalar(canonicalBigEndian: Array(signature.prefix(32))),
				!r.isZero
			else {
				return false
			}
			guard let s = Scalar(canonicalBigEndian: Array(signature.suffix(32))),
				!s.isZero
			else {
				return false
			}
			guard let publicKey = Point(compressed: compressedPublicKey) else {
				return false
			}

			let z = Scalar(reducingBigEndian: Array(digest))
			let w = s.inverted
			let u1 = z * w
			let u2 = r * w

			let sum = Point.generator.multiplied(by: u1) + publicKey.multiplied(by: u2)
			guard let x = sum.affine?.x else { return false }

			//R.x is an element of F_p; the comparison against r is mod n, per
			//the algorithm — folding through the same `reducingBigEndian` path
			//`z` used keeps this one reduction routine instead of a second,
			//parallel one.
			return Scalar(reducingBigEndian: x.bigEndianBytes) == r
		}
	}
}
