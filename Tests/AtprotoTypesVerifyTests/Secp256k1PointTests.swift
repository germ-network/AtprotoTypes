//
//  Secp256k1PointTests.swift
//  AtprotoTypesVerifyTests
//
//  Created by Mark @ Germ on 8/17/26.
//

import Foundation
import Testing

@testable import AtprotoTypesVerify

@Suite("secp256k1 points")
struct Secp256k1PointTests {
	typealias Point = Secp256k1.Point
	typealias Field = Secp256k1.Field
	typealias Scalar = Secp256k1.Scalar

	static func field(_ hex: String) -> Field {
		Field(bigEndian: Array(Data(hex: hex)))!
	}

	static func scalar(_ value: UInt8) -> Scalar {
		Scalar(canonicalBigEndian: [UInt8](repeating: 0, count: 31) + [value])!
	}

	@Test("the generator is on the curve: y^2 == x^3 + 7")
	func generatorIsOnCurve() throws {
		let (x, y) = try #require(Point.generator.affine)
		#expect(y.squared() == x.squared() * x + Point.b)
	}

	///Independently computed via a plain-Python affine short-Weierstrass
	///implementation (not this codebase), so this pins the whole arithmetic
	///stack — field ops, doubling, addition — against an outside reference
	///rather than against its own internal consistency.
	@Test("2G matches an independently computed reference value")
	func doublingMatchesKnownAnswer() throws {
		let doubled = Point.generator.doubled()
		let (x, y) = try #require(doubled.affine)
		#expect(
			x
				== Self.field(
					"C6047F9441ED7D6D3045406E95C07CD85C778E4B8CEF3CA7ABAC09B95C709EE5"
				))
		#expect(
			y
				== Self.field(
					"1AE168FEA63DC339A3C58419466CEAEEF7F632653266D0E1236431A950CFE52A"
				))

		//routed through addition and through scalar multiplication too, since
		//doubling is a distinct code path from both
		let viaAddition = Point.generator + Point.generator
		#expect(viaAddition.affine?.x == x)
		#expect(viaAddition.affine?.y == y)

		let viaMultiply = Point.generator.multiplied(by: Self.scalar(2))
		#expect(viaMultiply.affine?.x == x)
		#expect(viaMultiply.affine?.y == y)
	}

	@Test("3G matches an independently computed reference value")
	func triplingMatchesKnownAnswer() throws {
		let tripled = (Point.generator + Point.generator) + Point.generator
		let (x, y) = try #require(tripled.affine)
		#expect(
			x
				== Self.field(
					"F9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9"
				))
		#expect(
			y
				== Self.field(
					"388F7B0F632DE8140FE337E62A37F3566500A99934C2231B6CB9FD7584B8E672"
				))

		let viaMultiply = Point.generator.multiplied(by: Self.scalar(3))
		#expect(viaMultiply.affine?.x == x)
		#expect(viaMultiply.affine?.y == y)
	}

	// MARK: - Infinity

	@Test("infinity is the identity for addition")
	func infinityIsIdentity() {
		#expect(Point.generator + Point.infinity == Point.generator)
		#expect(Point.infinity + Point.generator == Point.generator)
	}

	@Test("doubling infinity is infinity")
	func doublingInfinityIsInfinity() {
		#expect(Point.infinity.doubled() == Point.infinity)
	}

	@Test("a point plus its negation is infinity")
	func pointPlusNegationIsInfinity() {
		#expect(Point.generator + Point.generator.negated == Point.infinity)
	}

	@Test("infinity has no affine representation")
	func infinityHasNoAffine() {
		#expect(Point.infinity.affine == nil)
	}

	///Compared via affine coordinates, not raw `Point ==`: two different
	///Jacobian triples (X, Y, Z) can represent the same affine point — a
	///fresh scalar multiplication accumulates an arbitrary Z, while
	///`negated` reuses the generator's own Z=1 — so `Point`'s structural
	///equality is only meaningful against the literal `.infinity` case, never
	///between two points that might carry different Z scalings.
	@Test("(n-1)*G equals -G")
	func scalarMultiplicationByOrderMinusOneNegatesTheGenerator() throws {
		let nMinus1 = Scalar(
			canonicalBigEndian: Array(
				Data(
					hex:
						"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364140"
				)))!
		let result = try #require(Point.generator.multiplied(by: nMinus1).affine)
		let expected = try #require(Point.generator.negated.affine)
		#expect(result.x == expected.x)
		#expect(result.y == expected.y)
	}

	// MARK: - Decompression

	@Test("a compressed generator decompresses to the generator")
	func decompressesGenerator() throws {
		var compressed = Data([Point.generator.affine!.y.isOdd ? 0x03 : 0x02])
		compressed.append(contentsOf: Point.generator.affine!.x.bigEndianBytes)

		let decoded = try #require(Point(compressed: compressed))
		#expect(decoded.affine?.x == Point.generator.affine?.x)
		#expect(decoded.affine?.y == Point.generator.affine?.y)
	}

	@Test("both parity prefixes round-trip to the correct y")
	func decompressionRespectsParity() throws {
		let (x, y) = Point.generator.affine!
		let evenPrefix: UInt8 = y.isOdd ? 0x03 : 0x02  //the prefix matching y as-is
		let oddPrefix: UInt8 = y.isOdd ? 0x02 : 0x03  //the prefix for -y

		var asIs = Data([evenPrefix])
		asIs.append(contentsOf: x.bigEndianBytes)
		let decodedAsIs = try #require(Point(compressed: asIs))
		#expect(decodedAsIs.affine?.y == y)

		var negated = Data([oddPrefix])
		negated.append(contentsOf: x.bigEndianBytes)
		let decodedNegated = try #require(Point(compressed: negated))
		#expect(decodedNegated.affine?.y == y.negated)
	}

	@Test("an x with no corresponding curve point is rejected")
	func rejectsXNotOnCurve() {
		//x = 5: 5^3 + 7 = 132, and 132 is not a quadratic residue mod p
		//(checked independently — if this ever flips due to a p
		//transcription error, this test starts failing loudly rather than
		//silently accepting)
		var compressed = Data([0x02])
		compressed.append(contentsOf: [UInt8](repeating: 0, count: 31) + [5])
		#expect(Point(compressed: compressed) == nil)
	}

	@Test("x equal to or above p is rejected")
	func rejectsXAboveModulus() {
		var compressed = Data([0x02])
		compressed.append(
			contentsOf: Data(
				hex:
					"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F"
			))  //== p
		#expect(Point(compressed: compressed) == nil)
	}

	@Test("wrong length is rejected")
	func rejectsWrongLength() {
		#expect(Point(compressed: Data([0x02, 0x01])) == nil)
	}

	@Test("wrong prefix byte is rejected")
	func rejectsWrongPrefix() {
		var compressed = Data([0x04])
		compressed.append(contentsOf: Point.generator.affine!.x.bigEndianBytes)
		#expect(Point(compressed: compressed) == nil)
	}
}
