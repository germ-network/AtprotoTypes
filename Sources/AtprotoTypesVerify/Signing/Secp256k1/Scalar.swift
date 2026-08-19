//
//  Scalar.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 8/17/26.
//

import Foundation

///An element of Z/nZ, n being secp256k1's group order.
///
///Same posture as `Field`: verify-only, no secrets, so not constant-time.
///See that file's note — it applies here unchanged.
extension Secp256k1 {
	struct Scalar: Sendable, Equatable {
		///Always reduced: `0 <= value < n`.
		let value: Limbs

		///n, the order of the generator.
		static let order: Limbs = (
			0xBFD2_5E8C_D036_4141,
			0xBAAE_DCE6_AF48_A03B,
			0xFFFF_FFFF_FFFF_FFFE,
			0xFFFF_FFFF_FFFF_FFFF
		)

		///2^256 - n, so 2^256 ≡ this (mod n) — n has no reduction shortcut as
		///clean as p's, so folding uses the same technique against this
		///180-bit constant instead of a small one. Computed from `order`
		///rather than written out: a 64-digit hex constant transcribed by
		///hand is a second chance to be quietly wrong, alongside `order`
		///itself, in a way only a rare vector would catch.
		private static let foldFactor: Limbs = {
			let complement: Limbs = (~order.0, ~order.1, ~order.2, ~order.3)
			return Limbs256.adding(complement, Limbs256.one).0
		}()

		static let zero = Scalar(unchecked: Limbs256.zero)
		static let one = Scalar(unchecked: Limbs256.one)

		private init(unchecked value: Limbs) {
			self.value = value
		}

		static func == (lhs: Scalar, rhs: Scalar) -> Bool {
			Limbs256.compare(lhs.value, rhs.value) == 0
		}

		///For signature components, which must already be canonical — an
		///out-of-range `r` or `s` is a malformed signature, not something to
		///reduce into range.
		init?(canonical value: Limbs) {
			guard Limbs256.compare(value, Self.order) < 0 else { return nil }
			self.value = value
		}

		init?(canonicalBigEndian bytes: [UInt8]) {
			guard let limbs = Limbs256.from(bigEndian: bytes) else { return nil }
			self.init(canonical: limbs)
		}

		///For the message digest, which ECDSA *does* reduce mod n. A SHA-256
		///output can exceed n, and folding it is part of the algorithm rather
		///than a leniency.
		init(reducingBigEndian bytes: [UInt8]) {
			guard let limbs = Limbs256.from(bigEndian: bytes) else {
				self.value = Limbs256.zero
				return
			}
			var reduced = limbs
			while Limbs256.compare(reduced, Self.order) >= 0 {
				reduced = Limbs256.subtracting(reduced, Self.order).0
			}
			self.value = reduced
		}

		var isZero: Bool { Limbs256.isZero(value) }
		var bigEndianBytes: [UInt8] { Limbs256.bigEndianBytes(value) }

		// MARK: - Arithmetic

		static func * (lhs: Scalar, rhs: Scalar) -> Scalar {
			reduce(Limbs256.multiplyWide(lhs.value, rhs.value))
		}

		///Folds using 2^256 ≡ foldFactor (mod n). Each pass's leftover high
		///part is roughly `foldFactor`'s own width (~129 bits) narrower than
		///the one before it, so this converges in a handful of passes, well
		///inside the loop bound — and the trailing subtraction loop mops up
		///whatever remains below 2^256.
		static func reduce(_ wide: [UInt64]) -> Scalar {
			var buffer = wide

			var pass = 0
			while !(buffer[4] == 0 && buffer[5] == 0 && buffer[6] == 0
				&& buffer[7] == 0)
			{
				pass += 1
				precondition(pass < 12, "scalar reduction did not converge")

				let high: Limbs = (buffer[4], buffer[5], buffer[6], buffer[7])
				let product = Limbs256.multiplyWide(high, foldFactor)

				var next = [UInt64](repeating: 0, count: 8)
				next[0] = buffer[0]
				next[1] = buffer[1]
				next[2] = buffer[2]
				next[3] = buffer[3]
				for (index, limb) in product.enumerated() {
					Limbs256.rippleAdd(limb, at: index, into: &next)
				}
				buffer = next
			}

			var result: Limbs = (buffer[0], buffer[1], buffer[2], buffer[3])
			while Limbs256.compare(result, order) >= 0 {
				result = Limbs256.subtracting(result, order).0
			}
			return Scalar(unchecked: result)
		}

		private static let inverseExponent = Limbs256.subtracting(order, (2, 0, 0, 0)).0

		///Fermat's little theorem (n is prime). Only ever called on `s` in the
		///ECDSA verify equation, which has already been checked non-zero.
		var inverted: Scalar {
			var result = Scalar.one
			for limbIndex in stride(from: 3, through: 0, by: -1) {
				let limb = Limbs256[Self.inverseExponent, limbIndex]
				for bit in stride(from: 63, through: 0, by: -1) {
					result = result * result
					if (limb >> UInt64(bit)) & 1 == 1 {
						result = result * self
					}
				}
			}
			return result
		}

		// MARK: - Malleability

		///n/2, for the low-S rule — mirrors `RepoSigningKey.isLowS`'s existing
		///shape exactly, against this curve's own order.
		static let halfOrder = Limbs256.shiftedRight(order, by: 1)

		var isLowS: Bool {
			Limbs256.compare(value, Self.halfOrder) <= 0
		}
	}
}
