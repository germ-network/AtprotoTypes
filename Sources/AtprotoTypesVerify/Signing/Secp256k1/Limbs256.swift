//
//  Limbs256.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 8/17/26.
//

import Foundation

///256-bit unsigned integers as four `UInt64` limbs, least significant first —
///not `UInt128`, deliberately: this package floors at iOS 16 / macOS 13, and
///the stdlib's `UInt128` needs iOS 18 / macOS 15. `multipliedFullWidth(by:)`
///gives the same 128-bit intermediate a `UInt128` product would, without the
///floor bump.
enum Secp256k1 {}

extension Secp256k1 {
	typealias Limbs = (UInt64, UInt64, UInt64, UInt64)

	enum Limbs256 {
		static func from(bigEndian bytes: [UInt8]) -> Limbs? {
			guard bytes.count == 32 else { return nil }
			func word(_ start: Int) -> UInt64 {
				var value: UInt64 = 0
				for index in start..<(start + 8) {
					value = (value << 8) | UInt64(bytes[index])
				}
				return value
			}
			return (word(24), word(16), word(8), word(0))
		}

		static func bigEndianBytes(_ value: Limbs) -> [UInt8] {
			var out = [UInt8]()
			out.reserveCapacity(32)
			for word in [value.3, value.2, value.1, value.0] {
				for shift in stride(from: 56, through: 0, by: -8) {
					out.append(UInt8(truncatingIfNeeded: word >> UInt64(shift)))
				}
			}
			return out
		}

		static subscript(_ value: Limbs, _ index: Int) -> UInt64 {
			switch index {
			case 0: value.0
			case 1: value.1
			case 2: value.2
			default: value.3
			}
		}

		static let zero: Limbs = (0, 0, 0, 0)
		static let one: Limbs = (1, 0, 0, 0)

		static func isZero(_ value: Limbs) -> Bool {
			value.0 == 0 && value.1 == 0 && value.2 == 0 && value.3 == 0
		}

		///Not constant-time. Every value compared during verification is
		///public — the whole point of a verify-only port — so there is no
		///secret whose timing could leak, and a straightforward branching
		///comparison is the honest, easy-to-audit choice.
		static func compare(_ lhs: Limbs, _ rhs: Limbs) -> Int {
			if lhs.3 != rhs.3 { return lhs.3 < rhs.3 ? -1 : 1 }
			if lhs.2 != rhs.2 { return lhs.2 < rhs.2 ? -1 : 1 }
			if lhs.1 != rhs.1 { return lhs.1 < rhs.1 ? -1 : 1 }
			if lhs.0 != rhs.0 { return lhs.0 < rhs.0 ? -1 : 1 }
			return 0
		}

		static func adding(_ lhs: Limbs, _ rhs: Limbs) -> (Limbs, carry: UInt64) {
			var result = [UInt64](repeating: 0, count: 4)
			var carry: UInt64 = 0
			let l = [lhs.0, lhs.1, lhs.2, lhs.3]
			let r = [rhs.0, rhs.1, rhs.2, rhs.3]
			for index in 0..<4 {
				let (sum1, o1) = l[index].addingReportingOverflow(r[index])
				let (sum2, o2) = sum1.addingReportingOverflow(carry)
				result[index] = sum2
				carry = (o1 ? 1 : 0) &+ (o2 ? 1 : 0)
			}
			return ((result[0], result[1], result[2], result[3]), carry)
		}

		static func subtracting(_ lhs: Limbs, _ rhs: Limbs) -> (Limbs, borrow: UInt64) {
			var result = [UInt64](repeating: 0, count: 4)
			var borrow: UInt64 = 0
			let l = [lhs.0, lhs.1, lhs.2, lhs.3]
			let r = [rhs.0, rhs.1, rhs.2, rhs.3]
			for index in 0..<4 {
				let (diff1, u1) = l[index].subtractingReportingOverflow(r[index])
				let (diff2, u2) = diff1.subtractingReportingOverflow(borrow)
				result[index] = diff2
				borrow = (u1 ? 1 : 0) &+ (u2 ? 1 : 0)
			}
			return ((result[0], result[1], result[2], result[3]), borrow)
		}

		///Adds `value` at `position` in an 8-limb accumulator, rippling the
		///carry forward through as many further positions as it takes. This is
		///the one primitive `multiplyWide` and the reduction routines build on;
		///keeping it this literal — rather than folding a product's high word
		///and two borrowed carry flags into one addition by hand — is what
		///makes the accumulation provably lossless instead of merely
		///believed so: a hand-fused add can undercount by exactly one in a
		///narrow edge case (large product, both inputs already near
		///`UInt64.max`), and that is not a bug a quick reading catches.
		static func rippleAdd(
			_ value: UInt64, at position: Int, into accumulator: inout [UInt64]
		) {
			var carry = value
			var index = position
			while carry != 0 {
				precondition(
					index < accumulator.count,
					"carry overflowed the accumulator")
				let (sum, overflow) = accumulator[index].addingReportingOverflow(
					carry)
				accumulator[index] = sum
				carry = overflow ? 1 : 0
				index += 1
			}
		}

		///Full 512-bit product as eight limbs, least significant first.
		static func multiplyWide(_ lhs: Limbs, _ rhs: Limbs) -> [UInt64] {
			var result = [UInt64](repeating: 0, count: 8)
			let l = [lhs.0, lhs.1, lhs.2, lhs.3]
			let r = [rhs.0, rhs.1, rhs.2, rhs.3]
			for i in 0..<4 {
				for j in 0..<4 {
					let (hi, lo) = l[i].multipliedFullWidth(by: r[j])
					rippleAdd(lo, at: i + j, into: &result)
					rippleAdd(hi, at: i + j + 1, into: &result)
				}
			}
			return result
		}

		static func squareWide(_ value: Limbs) -> [UInt64] {
			multiplyWide(value, value)
		}

		///Only used for small in-limb shifts (0 < count < 64).
		static func shiftedRight(_ value: Limbs, by count: Int) -> Limbs {
			precondition(count > 0 && count < 64)
			let carryShift = UInt64(64 - count)
			let shift = UInt64(count)
			return (
				(value.0 >> shift) | (value.1 << carryShift),
				(value.1 >> shift) | (value.2 << carryShift),
				(value.2 >> shift) | (value.3 << carryShift),
				value.3 >> shift
			)
		}
	}
}
