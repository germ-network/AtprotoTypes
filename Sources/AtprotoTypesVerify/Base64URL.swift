//
//  Base64URL.swift
//  AtprotoTypesVerify
//
//  Created by Mark @ Germ on 10/18/26.
//

import Foundation

///Unpadded base64url, strict in the decoding direction.
///
///The `did:plc` signature is carried as base64url with no `=` padding, and the
///method specification requires the encoding to be enforced rather than
///tolerated: "non-canonical encodings or 'High-S' values [must be] rejected as
///invalid. Otherwise, it would be possible for the signature encoding to be
///modified (thus modifying the operation's CID) without invalidating the
///signature." Padding, an alternate alphabet and non-zero trailing bits are all
///second spellings of one signature, so a decoder that accepts them hands an
///attacker a way to change an operation's bytes while keeping its signature
///valid — which is exactly the malleability the rule exists to stop.
package enum Base64URL {
	package enum DecodeError: Error, Equatable, LocalizedError {
		///`=` padding is not part of the encoding the method specifies.
		case paddingNotAllowed
		case invalidCharacter(UInt8)
		///A trailing character whose low bits are not zero — RFC 4648 §3.5.
		case nonCanonicalTrailingBits
		///A length no base64url string can have.
		case invalidLength(Int)

		public var errorDescription: String? {
			switch self {
			case .paddingNotAllowed: "base64url padding is not allowed"
			case .invalidCharacter(let byte):
				"Invalid base64url character \(UnicodeScalar(byte))"
			case .nonCanonicalTrailingBits:
				"base64url trailing bits are not zero"
			case .invalidLength(let length): "Invalid base64url length \(length)"
			}
		}
	}

	private static let alphabet = Array(
		"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".utf8)

	package static func decode(_ text: String) throws -> Data {
		guard !text.utf8.contains(UInt8(ascii: "=")) else {
			throw DecodeError.paddingNotAllowed
		}
		let bytes = Array(text.utf8)
		//a length of 4n+1 can only be a truncated string: it would leave a whole
		//character's worth of bits with no byte to spend them on
		guard bytes.count % 4 != 1 else {
			throw DecodeError.invalidLength(bytes.count)
		}

		var out = Data()
		out.reserveCapacity(bytes.count / 4 * 3 + 3)
		var accumulator: UInt32 = 0
		var bits = 0
		for byte in bytes {
			guard let value = value(of: byte) else {
				throw DecodeError.invalidCharacter(byte)
			}
			accumulator = (accumulator << 6) | UInt32(value)
			bits += 6
			if bits >= 8 {
				bits -= 8
				out.append(UInt8((accumulator >> UInt32(bits)) & 0xFF))
				//keep only the bits that have not been spent, so the accumulator
				//cannot drift into an overflow on a long input
				accumulator &= (UInt32(1) << UInt32(bits)) - 1
			}
		}

		//RFC 4648 §3.5: the bits a final character does not contribute to a whole
		//byte must be zero, or the same bytes have a second spelling.
		guard accumulator == 0 else {
			throw DecodeError.nonCanonicalTrailingBits
		}
		return out
	}

	package static func encode(_ data: Data) -> String {
		var out = ""
		var accumulator: UInt32 = 0
		var bits = 0
		for byte in data {
			accumulator = (accumulator << 8) | UInt32(byte)
			bits += 8
			while bits >= 6 {
				bits -= 6
				out.unicodeScalars.append(
					UnicodeScalar(
						alphabet[Int((accumulator >> UInt32(bits)) & 0x3F)])
				)
			}
			accumulator &= (UInt32(1) << UInt32(bits)) - 1
		}
		//the leftover bits are padded out with zeros and emitted as one last
		//character, which is what leaves the output unpadded
		if bits > 0 {
			out.unicodeScalars.append(
				UnicodeScalar(
					alphabet[Int((accumulator << UInt32(6 - bits)) & 0x3F)]))
		}
		return out
	}

	private static func value(of byte: UInt8) -> UInt8? {
		switch byte {
		case UInt8(ascii: "A")...UInt8(ascii: "Z"): byte - UInt8(ascii: "A")
		case UInt8(ascii: "a")...UInt8(ascii: "z"): byte - UInt8(ascii: "a") + 26
		case UInt8(ascii: "0")...UInt8(ascii: "9"): byte - UInt8(ascii: "0") + 52
		case UInt8(ascii: "-"): 62
		case UInt8(ascii: "_"): 63
		default: nil
		}
	}
}
