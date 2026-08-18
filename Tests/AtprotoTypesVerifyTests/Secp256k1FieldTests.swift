//
//  Secp256k1FieldTests.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 8/17/26.
//

import Foundation
import Testing

@testable import AtprotoTypesVerify

@Suite("secp256k1 field arithmetic")
struct Secp256k1FieldTests {
	typealias Field = Secp256k1.Field

	static func field(_ hex: String) -> Field {
		Field(bigEndian: Array(Data(hex: hex)))!
	}

	@Test("p is exactly 2^256 - 2^32 - 977")
	func modulusMatchesClosedForm() {
		//built independently of the hardcoded limbs, from the textbook
		//definition (doubling 256 times from 1 gives 2^256, mod 2^256 —
		//which is exactly what four wrapping UInt64 limbs represent), so a
		//transcription error in the constant can't hide behind an equally
		//wrong derivation
		var twoTo256 = Secp256k1.Limbs256.one
		for _ in 0..<256 { twoTo256 = Secp256k1.Limbs256.adding(twoTo256, twoTo256).0 }
		#expect(Secp256k1.Limbs256.compare(twoTo256, Secp256k1.Limbs256.zero) == 0)

		let twoTo32: UInt64 = 1 << 32
		var reference = Secp256k1.Limbs256.zero
		reference = Secp256k1.Limbs256.subtracting(reference, (twoTo32, 0, 0, 0)).0
		reference = Secp256k1.Limbs256.subtracting(reference, (977, 0, 0, 0)).0
		#expect(Secp256k1.Limbs256.compare(reference, Field.modulus) == 0)
	}

	@Test("p - 1 + 1 wraps to zero")
	func wrapsAtModulus() {
		let pMinus1 = Field.zero - Field.one
		#expect(pMinus1 + Field.one == Field.zero)
	}

	@Test("0 - 1 == p - 1")
	func subtractionUnderflowsCorrectly() {
		let direct = Field.zero - Field.one
		let expected = Self.field("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2E")
		#expect(direct == expected)
	}

	static func small(_ value: UInt8) -> Field {
		Field(bigEndian: [UInt8](repeating: 0, count: 31) + [value])!
	}

	@Test("multiplication agrees with repeated addition for small values")
	func multiplicationMatchesRepeatedAddition() {
		let seven = Self.small(7)
		var bySum = Field.zero
		for _ in 0..<41 { bySum = bySum + seven }
		#expect(bySum == seven * Self.small(41))
	}

	///The case the carry-propagation logic in `Limbs256.multiplyWide` exists
	///for: both operands at the top of the limb range, where a hand-fused
	///carry addition (rather than the rippling one this uses) can silently
	///drop a carry.
	@Test("multiplying two near-maximal field elements does not lose a carry")
	func multiplicationOfLargeValuesRoundTrips() {
		let pMinus1 = Self.field("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2E")
		let product = pMinus1 * pMinus1
		//p-1 ≡ -1 (mod p), so (p-1)^2 ≡ (-1)^2 == 1
		#expect(product == Field.one)

		//a second, less degenerate near-maximal case: p-2 ≡ -2, so
		//(p-2)^2 ≡ 4 — a non-trivial answer a dropped carry is less likely
		//to accidentally still land on
		let pMinus2 = Self.field("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2D")
		#expect(pMinus2 * pMinus2 == Self.small(4))
	}

	@Test("inverse: a * a^-1 == 1 for several values")
	func inverseRoundTrips() throws {
		for hex in [
			"0000000000000000000000000000000000000000000000000000000000000002",
			"0000000000000000000000000000000000000000000000000000000000000003",
			"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2E",
		] {
			let value = Self.field(hex)
			#expect(value * value.inverted == Field.one)
		}
	}

	@Test("square root: sqrt(a^2) squares back to a^2")
	func squareRootRoundTrips() throws {
		let value = Self.field("0000000000000000000000000000000000000000000000000000000000000005")
		let squared = value.squared()
		let root = try #require(squared.squareRoot)
		#expect(root.squared() == squared)
	}

	@Test("square root of a non-residue is nil")
	func squareRootOfNonResidueIsNil() {
		//3 is a quadratic non-residue mod secp256k1's p (p ≡ 3 mod 4, and 3's
		//Legendre symbol here is -1 — verified against a reference computation)
		let three = Self.field("0000000000000000000000000000000000000000000000000000000000000003")
		#expect(three.squareRoot == nil)
	}

	@Test("canonical init rejects a value equal to or above the modulus")
	func rejectsNonCanonicalValues() {
		#expect(Field(bigEndian: Array(Data(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F"))) == nil)  //== p
		#expect(Field(bigEndian: Array(Data(hex: "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF"))) == nil)  //> p
	}
}
