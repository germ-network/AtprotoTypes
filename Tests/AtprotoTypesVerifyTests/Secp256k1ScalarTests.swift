//
//  Secp256k1ScalarTests.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 8/17/26.
//

import Foundation
import Testing

@testable import AtprotoTypesVerify

@Suite("secp256k1 scalar arithmetic")
struct Secp256k1ScalarTests {
	typealias Scalar = Secp256k1.Scalar

	static func scalar(_ hex: String) -> Scalar {
		Scalar(canonicalBigEndian: Array(Data(hex: hex)))!
	}

	static func small(_ value: UInt8) -> Scalar {
		Scalar(canonicalBigEndian: [UInt8](repeating: 0, count: 31) + [value])!
	}

	@Test("n - 1, doubled and reduced by hand, matches the closed-form order")
	func orderIsInternallyConsistent() {
		//n itself is not representable as a canonical Scalar (by definition —
		//canonical means < n), so this checks 2n reduces to 0 via the same
		//wide-reduction path everything else uses
		let wide = Secp256k1.Limbs256.multiplyWide(Scalar.order, (2, 0, 0, 0))
		let reduced = Scalar.reduce(wide)
		#expect(reduced == Scalar.zero)
	}

	@Test("n - 1 + 1 wraps to zero")
	func wrapsAtOrder() {
		let nMinus1 = Self.scalar(
			"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364140")
		#expect(Self.adding(nMinus1, Scalar.one) == Scalar.zero)
	}

	///Adds two scalar values via the shared limb primitive — a plain `+`
	///isn't part of `Scalar`'s production surface (ECDSA verify only needs
	///multiplication and inversion), so tests reach for the same primitive
	///`Scalar.reduce`'s own callers do rather than growing the type an
	///operator nothing else uses.
	static func adding(_ lhs: Scalar, _ rhs: Scalar) -> Scalar {
		let (sum, carry) = Secp256k1.Limbs256.adding(lhs.value, rhs.value)
		return Scalar.reduce([sum.0, sum.1, sum.2, sum.3, carry, 0, 0, 0])
	}

	@Test("multiplication agrees with repeated addition for small values")
	func multiplicationMatchesRepeatedAddition() {
		let seven = Self.small(7)
		var bySum = Scalar.zero
		for _ in 0..<41 { bySum = Self.adding(bySum, seven) }
		#expect(bySum == seven * Self.small(41))
	}

	///The same near-maximal carry-loss probe as `Field`'s, against n instead
	///of p, and against `foldFactor` (129 bits, not p's 33) — a wider fold
	///constant is a different opportunity to drop a carry across more limbs.
	@Test("multiplying two near-maximal scalars does not lose a carry")
	func multiplicationOfLargeValuesRoundTrips() {
		let nMinus1 = Self.scalar(
			"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364140")
		#expect(nMinus1 * nMinus1 == Scalar.one)  //(-1)^2 == 1

		let nMinus2 = Self.scalar(
			"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD036413F")
		#expect(nMinus2 * nMinus2 == Self.small(4))  //(-2)^2 == 4
	}

	@Test("inverse: a * a^-1 == 1 for several values")
	func inverseRoundTrips() {
		for hex in [
			"0000000000000000000000000000000000000000000000000000000000000002",
			"0000000000000000000000000000000000000000000000000000000000000003",
			"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364140",
		] {
			let value = Self.scalar(hex)
			#expect(value * value.inverted == Scalar.one)
		}
	}

	@Test("low-S: exactly n/2 is low, n/2 + 1 is high")
	func lowSBoundary() {
		let half = Scalar(canonical: Scalar.halfOrder)!
		#expect(half.isLowS)
		#expect(!Self.adding(half, Scalar.one).isLowS)
	}

	@Test("digest reduction folds a full 32-byte SHA-256-sized value mod n")
	func digestReductionHandlesOversizedInput() {
		//all-0xFF is well above n; the reducing init must fold it, not reject
		//it the way the canonical init would
		let maxDigest = [UInt8](repeating: 0xFF, count: 32)
		let reduced = Scalar(reducingBigEndian: maxDigest)
		#expect(Secp256k1.Limbs256.compare(reduced.value, Scalar.order) < 0)
	}

	@Test("canonical init rejects a value equal to or above the order")
	func rejectsNonCanonicalValues() {
		#expect(
			Scalar(
				canonicalBigEndian: Array(
					Data(
						hex:
							"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141"
					))
			) == nil)  //== n
	}
}
