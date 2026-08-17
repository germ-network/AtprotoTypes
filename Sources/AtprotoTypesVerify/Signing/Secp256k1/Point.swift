//
//  Point.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 8/17/26.
//

import Foundation

///A point on secp256k1: y² = x³ + 7 (a = 0, b = 7), in Jacobian coordinates
///(X, Y, Z) representing the affine point (X/Z², Y/Z³). Jacobian avoids a
///field inversion per point operation — this pays exactly one, in
///`affine()`, at the end of a scalar multiplication.
///
///Same posture as `Field`/`Scalar`: verify-only, not constant-time — every
///point here (a public key, an intermediate in `u1·G + u2·Q`) is public.
extension Secp256k1 {
	///`Equatable` only compares raw (X, Y, Z) triples — safe against the
	///literal `.infinity` case, since it carries no coordinates, but two
	///different Jacobian triples can represent the same affine point (a
	///fresh scalar multiplication accumulates an arbitrary Z; a value built
	///directly, like `.negated`, may keep its input's Z). Comparing two
	///non-infinity points for equality means comparing `.affine` values, not
	///`==` on the `Point` itself.
	enum Point: Sendable, Equatable {
		///The identity of point addition. An explicit case rather than a
		///sentinel coordinate (e.g. `Z == 0` folded into the general formulas)
		///— infinity-handling bugs are the classic failure mode for curve
		///code, and a case the compiler makes you switch on is harder to
		///silently mishandle than a coordinate convention is.
		case infinity
		case affinePoint(x: Field, y: Field, z: Field)

		static func jacobian(x: Field, y: Field, z: Field) -> Point {
			.affinePoint(x: x, y: y, z: z)
		}

		///b = 7 in y² = x³ + 7.
		static let b = Field(bigEndian: [UInt8](repeating: 0, count: 31) + [7])!

		///The generator point, from the standard secp256k1 domain parameters.
		static let generator: Point = {
			let x = Field(
				bigEndian: Array(
					hex: "79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798"))!
			let y = Field(
				bigEndian: Array(
					hex: "483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8"))!
			return .jacobian(x: x, y: y, z: Field.one)
		}()

		// MARK: - Doubling and addition

		///Standard Jacobian doubling for a = 0 curves.
		func doubled() -> Point {
			guard case .affinePoint(let x1, let y1, let z1) = self else { return .infinity }
			if y1.isZero { return .infinity }  //a point of order 2, which secp256k1 has none of except this degenerate input

			let a = x1.squared()
			let b = y1.squared()
			let c = b.squared()
			let xPlusB = x1 + b
			let d = (xPlusB.squared() - a - c) + (xPlusB.squared() - a - c)
			let e = a + a + a
			let f = e.squared()
			let x3 = f - d - d
			let y3 = e * (d - x3) - (c + c + c + c + c + c + c + c)
			let z3 = (y1 * z1) + (y1 * z1)

			return .jacobian(x: x3, y: y3, z: z3)
		}

		///Standard Jacobian addition. Dispatches to `doubled()` when the two
		///points coincide — the classic bug in a naive Jacobian add, which
		///produces the wrong answer (or a spurious infinity) for `P + P`
		///because the general formula's `H = U2 - U1` denominator-equivalent
		///vanishes exactly when it must not.
		static func + (lhs: Point, rhs: Point) -> Point {
			guard case .affinePoint(let x1, let y1, let z1) = lhs else { return rhs }
			guard case .affinePoint(let x2, let y2, let z2) = rhs else { return lhs }

			let z1z1 = z1.squared()
			let z2z2 = z2.squared()
			let u1 = x1 * z2z2
			let u2 = x2 * z1z1
			let s1 = y1 * z2 * z2z2
			let s2 = y2 * z1 * z1z1

			if u1 == u2 {
				//same x: either the same point (double it) or additive
				//inverses (the result is infinity)
				return s1 == s2 ? lhs.doubled() : .infinity
			}

			let h = u2 - u1
			let doubleH = h + h
			let i = doubleH.squared()
			let j = h * i
			let r = (s2 - s1) + (s2 - s1)
			let v = u1 * i
			let x3 = r.squared() - j - v - v
			let y3 = r * (v - x3) - (s1 * j + s1 * j)
			let sumZ = z1 + z2
			let z3 = (sumZ.squared() - z1z1 - z2z2) * h

			return .jacobian(x: x3, y: y3, z: z3)
		}

		var negated: Point {
			guard case .affinePoint(let x, let y, let z) = self else { return .infinity }
			return .jacobian(x: x, y: y.negated, z: z)
		}

		// MARK: - Scalar multiplication

		///Double-and-add, most significant bit first. Not constant-time —
		///deliberately, see the file header — which is what makes the
		///straightforward textbook algorithm the right one here.
		func multiplied(by scalar: Scalar) -> Point {
			var result = Point.infinity
			for limbIndex in stride(from: 3, through: 0, by: -1) {
				let limb = Limbs256[scalar.value, limbIndex]
				for bit in stride(from: 63, through: 0, by: -1) {
					result = result.doubled()
					if (limb >> UInt64(bit)) & 1 == 1 {
						result = result + self
					}
				}
			}
			return result
		}

		// MARK: - Affine conversion

		///The one inversion a scalar multiplication pays. `nil` only for
		///infinity, which has no affine representation.
		var affine: (x: Field, y: Field)? {
			guard case .affinePoint(let x, let y, let z) = self else { return nil }
			let zInverted = z.inverted
			let zInvertedSquared = zInverted.squared()
			return (x * zInvertedSquared, y * zInvertedSquared * zInverted)
		}
	}
}

extension Array where Element == UInt8 {
	fileprivate init(hex: String) {
		var bytes: [UInt8] = []
		var index = hex.startIndex
		while index < hex.endIndex,
			let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex)
		{
			bytes.append(UInt8(hex[index..<next], radix: 16) ?? 0)
			index = next
		}
		self = bytes
	}
}
