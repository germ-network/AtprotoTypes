//
//  ServiceEndpoint.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 7/25/26.
//

import Darwin
import Foundation
import Network

extension Atproto.DIDDocument.Service {
	/// A DID document is supplied by a resolver, so its `serviceEndpoint` is
	/// attacker-influenced input that we then use as the base URL for both
	/// credentialed and public traffic. Reject the schemes and hosts that would
	/// turn that into an SSRF primitive before the URL escapes this type.
	package static func validate(endpoint: URL) throws {
		guard endpoint.scheme?.lowercased() == "https" else {
			throw Atproto.DIDDocument.Errors
				.insecureServiceUrlScheme(endpoint.scheme)
		}

		//already strips the brackets around an IPv6 literal
		let host = endpoint.host(percentEncoded: false) ?? ""

		guard permitted(host: host) else {
			throw Atproto.DIDDocument.Errors.disallowedServiceUrlHost(host)
		}
	}

	static func permitted(host rawHost: String) -> Bool {
		var host = rawHost.lowercased()
		//a trailing dot is the same name in FQDN form
		if host.hasSuffix(".") {
			host.removeLast()
		}
		//defensive: URL.host() unwraps these, URLComponents.host does not
		if host.hasPrefix("["), host.hasSuffix("]") {
			host = String(host.dropFirst().dropLast())
		}

		guard !host.isEmpty else { return false }

		if host == "localhost" || host.hasSuffix(".localhost") { return false }

		//One string can name different addresses depending on who parses it:
		//`0177.0.0.1` is 177.0.0.1 to IPv4Address and 127.0.0.1 to inet_aton,
		//and `010.0.0.1` splits the other way. We don't control which parser the
		//connection ultimately uses, so every reading has to be acceptable.
		if let v6 = IPv6Address(host), !permitted(v6) { return false }
		if let v4 = IPv4Address(host), !permitted(v4) { return false }
		if let legacy = inetAtonAddress(host), !permitted(legacy) { return false }

		return true
	}

	private static func permitted(_ address: IPv4Address) -> Bool {
		let bytes = [UInt8](address.rawValue)
		guard bytes.count == 4 else { return false }

		switch bytes[0] {
		case 0: return false  //0.0.0.0/8 unspecified, "this network"
		case 10: return false  //10/8 private
		case 127: return false  //127/8 loopback
		case 100: return !(64...127).contains(bytes[1])  //100.64/10 CGNAT
		case 169: return bytes[1] != 254  //169.254/16 link-local
		case 172: return !(16...31).contains(bytes[1])  //172.16/12 private
		case 192: return bytes[1] != 168  //192.168/16 private
		case 224...255: return false  //224/3 multicast, reserved, broadcast
		default: return true
		}
	}

	private static func permitted(_ address: IPv6Address) -> Bool {
		//::ffff:127.0.0.1 and friends are the v4 ranges wearing a v6 hat
		if let mapped = address.asIPv4 {
			return permitted(mapped)
		}

		let bytes = [UInt8](address.rawValue)
		guard bytes.count == 16 else { return false }

		//:: unspecified and ::1 loopback
		if bytes.dropLast().allSatisfy({ $0 == 0 }), bytes[15] <= 1 { return false }
		//fe80::/10 link-local
		if bytes[0] == 0xfe, bytes[1] & 0xc0 == 0x80 { return false }
		//fc00::/7 unique local
		if bytes[0] & 0xfe == 0xfc { return false }
		//ff00::/8 multicast
		if bytes[0] == 0xff { return false }

		return true
	}

	///the legacy decimal/octal/hex forms `getaddrinfo` still honors
	private static func inetAtonAddress(_ host: String) -> IPv4Address? {
		var address = in_addr()
		guard host.withCString({ inet_aton($0, &address) }) == 1 else {
			return nil
		}
		return IPv4Address(withUnsafeBytes(of: address.s_addr) { Data($0) })
	}
}
