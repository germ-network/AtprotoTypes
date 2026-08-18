//
//  Field.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 8/17/26.
//

import Foundation

///An element of GF(p) for secp256k1's p = 2^256 - 2^32 - 977.
///
///**Not constant-time, deliberately.** This is verify-only: every value it
///ever touches — a public key, a signature, a message hash — is public, and
///there is no secret whose timing could leak. That is the property that made
///a from-scratch Swift port acceptable at all, and it is why the
///code here can use straightforward branching arithmetic rather than the
///contortions a signing implementation would need.
///
///**This file must never grow a signing path.** A private key here would be
///a vulnerability, not a feature — verify-only is the whole point.
extension Secp256k1 {
	struct Field: Sendable, Equatable {
		///Always reduced: `0 <= value < p`.
		let value: Limbs

		///Tuples compare structurally but do not conform to `Equatable` as a
		///protocol, so synthesis can't see through `value`'s type — spelled
		///out explicitly instead.
		static func == (lhs: Field, rhs: Field) -> Bool {
			Limbs256.compare(lhs.value, rhs.value) == 0
		}

		///p = 2^256 - 2^32 - 977
		static let modulus: Limbs = (
			0xFFFF_FFFE_FFFF_FC2F,
			0xFFFF_FFFF_FFFF_FFFF,
			0xFFFF_FFFF_FFFF_FFFF,
			0xFFFF_FFFF_FFFF_FFFF
		)

		///2^256 mod p — what the fast reduction folds the high half by, a
		///consequence of p's specific form (2^256 ≡ 2^32 + 977, mod p).
		private static let foldFactor: UInt64 = 0x1_0000_03D1

		static let zero = Field(unchecked: Limbs256.zero)
		static let one = Field(unchecked: Limbs256.one)

		private init(unchecked value: Limbs) {
			self.value = value
		}

		///Fails on a non-canonical value. For a public-key coordinate that is a
		///rejection, not something to silently reduce into range.
		init?(canonical value: Limbs) {
			guard Limbs256.compare(value, Self.modulus) < 0 else { return nil }
			self.value = value
		}

		init?(bigEndian bytes: [UInt8]) {
			guard let limbs = Limbs256.from(bigEndian: bytes) else { return nil }
			self.init(canonical: limbs)
		}

		var bigEndianBytes: [UInt8] { Limbs256.bigEndianBytes(value) }
		var isZero: Bool { Limbs256.isZero(value) }
		var isOdd: Bool { value.0 & 1 == 1 }

		// MARK: - Arithmetic

		static func + (lhs: Field, rhs: Field) -> Field {
			let (sum, carry) = Limbs256.adding(lhs.value, rhs.value)
			//a carry out means the true sum is >= 2^256 > p; one subtraction
			//suffices because both inputs are already below p
			if carry != 0 || Limbs256.compare(sum, modulus) >= 0 {
				return Field(unchecked: Limbs256.subtracting(sum, modulus).0)
			}
			return Field(unchecked: sum)
		}

		static func - (lhs: Field, rhs: Field) -> Field {
			let (difference, borrow) = Limbs256.subtracting(lhs.value, rhs.value)
			if borrow != 0 {
				return Field(unchecked: Limbs256.adding(difference, modulus).0)
			}
			return Field(unchecked: difference)
		}

		static func * (lhs: Field, rhs: Field) -> Field {
			reduce(Limbs256.multiplyWide(lhs.value, rhs.value))
		}

		func squared() -> Field {
			Self.reduce(Limbs256.squareWide(value))
		}

		var negated: Field {
			isZero ? self : Field(unchecked: Limbs256.subtracting(Self.modulus, value).0)
		}

		///Folds a 512-bit product down using 2^256 ≡ 2^32 + 977 (mod p): each
		///pass multiplies the high half by the 33-bit `foldFactor` and adds it
		///back into the low half, which is what the modulus's special form
		///buys — no division anywhere. Each pass's leftover high part is
		///roughly `foldFactor`'s own width (33 bits) narrower than the one
		///before it, so a handful of passes clears it — well inside the loop
		///bound below.
		static func reduce(_ wide: [UInt64]) -> Field {
			var buffer = wide

			var pass = 0
			while !(buffer[4] == 0 && buffer[5] == 0 && buffer[6] == 0 && buffer[7] == 0) {
				pass += 1
				precondition(pass < 8, "field reduction did not converge")

				let high: Limbs = (buffer[4], buffer[5], buffer[6], buffer[7])
				var next = [UInt64](repeating: 0, count: 8)
				next[0] = buffer[0]
				next[1] = buffer[1]
				next[2] = buffer[2]
				next[3] = buffer[3]

				//high * foldFactor, added into the low half starting at
				//position 0 — foldFactor is 33 bits, so each limb's product
				//can ripple up to two positions beyond where it starts
				for (index, limb) in [high.0, high.1, high.2, high.3].enumerated() {
					let (hi, lo) = limb.multipliedFullWidth(by: foldFactor)
					Limbs256.rippleAdd(lo, at: index, into: &next)
					Limbs256.rippleAdd(hi, at: index + 1, into: &next)
				}
				buffer = next
			}

			var result: Limbs = (buffer[0], buffer[1], buffer[2], buffer[3])
			while Limbs256.compare(result, modulus) >= 0 {
				result = Limbs256.subtracting(result, modulus).0
			}
			return Field(unchecked: result)
		}

		// MARK: - Exponentiation

		///Square-and-multiply over every bit, including leading zeros.
		///Wasteful and obviously correct, which is the right trade for code
		///that runs a handful of times per signature check.
		static func power(_ base: Field, _ exponent: Limbs) -> Field {
			var result = Field.one
			for limbIndex in stride(from: 3, through: 0, by: -1) {
				let limb = Limbs256[exponent, limbIndex]
				for bit in stride(from: 63, through: 0, by: -1) {
					result = result.squared()
					if (limb >> UInt64(bit)) & 1 == 1 {
						result = result * base
					}
				}
			}
			return result
		}

		///p - 2 and (p+1)/4, derived from the modulus rather than written out
		///as separate 64-digit hex constants — two independently-transcribed
		///constants is two chances to be quietly wrong in a way only a rare
		///vector would catch.
		private static let inverseExponent = Limbs256.subtracting(modulus, (2, 0, 0, 0)).0
		private static let sqrtExponent = Limbs256.shiftedRight(
			Limbs256.adding(modulus, Limbs256.one).0,
			by: 2
		)

		///Fermat's little theorem (p is prime). `zero` has no inverse and
		///callers must not ask; the one caller here (point-to-affine) checks
		///for infinity first.
		var inverted: Field {
			Self.power(self, Self.inverseExponent)
		}

		///A square root when one exists, else nil. p ≡ 3 (mod 4), so the
		///candidate is `a^((p+1)/4)` — and it is squared back to confirm,
		///because that formula returns a wrong answer rather than failing when
		///`self` is not a quadratic residue.
		var squareRoot: Field? {
			let candidate = Self.power(self, Self.sqrtExponent)
			return candidate.squared() == self ? candidate : nil
		}
	}
}
