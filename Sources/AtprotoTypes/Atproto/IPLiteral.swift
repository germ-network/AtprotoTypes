//
//  IPLiteral.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 8/17/26.
//

#if canImport(Darwin)
	import Darwin
#elseif canImport(Android)
	import Android
#elseif canImport(Bionic)
	import Bionic
#elseif canImport(Musl)
	import Musl
#elseif canImport(Glibc)
	import Glibc
#endif

/// The address readings ``Atproto/DIDDocument/Service/validate(endpoint:policy:)``
/// screens a host against. Network.framework is Apple-only, so these reproduce
/// what its `IPv4Address` / `IPv6Address` returned, on every platform the
/// package builds for.
///
/// Two IPv4 readings, deliberately: one string can name different addresses
/// depending on who parses it, and the caller rejects on any disagreement.
package enum IPLiteral {
	/// The permissive grammar `IPv4Address` accepts. In a dotted quad each part
	/// names one byte, `0x` honored as hex and a leading zero read as
	/// **decimal** (`0177.0.0.1` is 177.0.0.1). Every other shape defers to
	/// ``legacyV4(_:)``, because that is what `IPv4Address` does: `16843009` is
	/// 1.1.1.1, `127.1` is 127.0.0.1, and `010` is 0.0.0.8 — octal, so a
	/// dotless spelling with an 8 or 9 after a leading zero has no reading and
	/// falls to the single-label rule.
	///
	/// The one probed divergence from `IPv4Address` is a quad part of `0x` with
	/// no digits (`1.0x.2.3`), which read as zero there and has no reading
	/// here. Safe: a host with no reading loses the literal exemption and is
	/// screened as a name, and where the platform's `inet_aton` reads the
	/// spelling, ``legacyV4(_:)`` still screens that reading.
	package static func v4(_ host: String) -> [UInt8]? {
		let parts = host.split(separator: ".", omittingEmptySubsequences: false)
		guard parts.count == 4 else {
			return legacyV4(host)
		}

		let values = parts.compactMap(partValue)
		guard values.count == 4, values.allSatisfy({ $0 <= 0xff }) else {
			return nil
		}

		return values.map { UInt8($0) }
	}

	/// `inet_aton`'s reading of the same string, where a leading zero is octal
	/// (`0177.0.0.1` is 127.0.0.1 here and 177.0.0.1 to ``v4(_:)``). Left to the
	/// platform's own libc rather than reimplemented, since this is the reading
	/// `getaddrinfo` will give the connection that follows.
	package static func legacyV4(_ host: String) -> [UInt8]? {
		var address = in_addr()
		guard host.withCString({ inet_aton($0, &address) }) == 1 else {
			return nil
		}
		return withUnsafeBytes(of: address.s_addr) { [UInt8]($0) }
	}

	/// The 16 address bytes, ignoring any `%zone` suffix as `IPv6Address` does.
	package static func v6(_ host: String) -> [UInt8]? {
		let address = host.prefix { $0 != "%" }
		var bytes = [UInt8](repeating: 0, count: 16)
		guard String(address).withCString({ inet_pton(AF_INET6, $0, &bytes) }) == 1
		else {
			return nil
		}
		return bytes
	}

	/// The IPv4 address embedded in a v4-mapped (`::ffff:a.b.c.d`) or the
	/// deprecated v4-compatible (`::a.b.c.d`) form, matching
	/// `IPv6Address.asIPv4`. `::` and `::1` are the unspecified and loopback
	/// v6 addresses, not v4 spellings, so they read as nil and the caller
	/// screens them on the v6 path.
	package static func embeddedV4(in bytes: [UInt8]) -> [UInt8]? {
		guard bytes.count == 16, bytes.prefix(10).allSatisfy({ $0 == 0 }) else {
			return nil
		}

		let tail = Array(bytes.suffix(4))
		switch (bytes[10], bytes[11]) {
		case (0xff, 0xff): return tail
		case (0, 0):
			return tail.dropLast().allSatisfy({ $0 == 0 }) && tail[3] <= 1
				? nil : tail
		default: return nil
		}
	}

	private static func partValue(_ part: Substring) -> UInt32? {
		guard !part.isEmpty else { return nil }

		guard part.hasPrefix("0x") || part.hasPrefix("0X") else {
			//UInt32(_:radix:) would otherwise accept a leading + or -
			guard part.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
			return UInt32(part, radix: 10)
		}

		let digits = part.dropFirst(2)
		guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isHexDigit })
		else {
			return nil
		}
		return UInt32(digits, radix: 16)
	}
}
