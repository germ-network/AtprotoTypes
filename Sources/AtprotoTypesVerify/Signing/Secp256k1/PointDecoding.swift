//
//  PointDecoding.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 8/17/26.
//

import Foundation

///SEC1 compressed-point parsing: `0x02`/`0x03` ‖ 32-byte x → the affine point.
extension Secp256k1.Point {
	///`compressed` must be exactly 33 bytes: a `0x02` (even y) or `0x03` (odd
	///y) prefix, then the 32-byte x-coordinate. Rejects `x >= p` and any x
	///that is not on the curve (no square root of `x³ + 7` exists).
	init?(compressed: Data) {
		guard compressed.count == 33 else { return nil }
		let prefix = compressed[compressed.startIndex]
		guard prefix == 0x02 || prefix == 0x03 else { return nil }

		guard let x = Secp256k1.Field(bigEndian: Array(compressed.dropFirst())) else {
			return nil
		}

		let rhs = x.squared() * x + Secp256k1.Point.b
		guard let candidate = rhs.squareRoot else { return nil }

		let wantsOdd = prefix == 0x03
		let y = candidate.isOdd == wantsOdd ? candidate : candidate.negated

		self = .jacobian(x: x, y: y, z: Secp256k1.Field.one)
	}
}
