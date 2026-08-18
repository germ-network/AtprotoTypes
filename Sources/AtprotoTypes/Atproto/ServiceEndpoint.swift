//
//  ServiceEndpoint.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 7/25/26.
//

import Foundation

extension Atproto.DIDDocument {
	/// What ``Service/validate(endpoint:policy:)`` will accept. Strict unless
	/// the caller names otherwise, so nothing relaxes by omission.
	public struct EndpointPolicy: Sendable, Equatable {
		//no public memberwise init: `.default` and `.developmentLoopback` are
		//the only values a consumer outside the package can name
		let allowsInsecureLoopback: Bool

		///https to a public host — the only policy that belongs in a shipped build.
		public static let `default` = Self(allowsInsecureLoopback: false)

		///Additionally accepts http, and only to a loopback host, so a
		///development build can reach a PDS on the developer's own machine:
		///atproto's dev-env serves plain http on `localhost:2583`. The private,
		///CGNAT, link-local, and reserved-TLD rules still apply, so this opens
		///the local machine and not the local network.
		public static let developmentLoopback = Self(allowsInsecureLoopback: true)
	}
}

extension Atproto.DIDDocument.Service {
	/// A DID document is supplied by a resolver, so its `serviceEndpoint` is
	/// attacker-influenced input that we then use as the base URL for both
	/// credentialed and public traffic. Reject the schemes and hosts that would
	/// turn that into an SSRF primitive. Reach the endpoint through ``pdsUrl``
	/// or ``checkServiceForAtproto(policy:)`` — reading ``service`` directly
	/// hands back a URL nothing has screened.
	///
	/// This is a name-level contract: it rejects reserved-address literals in
	/// every spelling the platform's parsers accept, plus name space that is
	/// defined to resolve locally. It does not resolve names, so it cannot see
	/// a public name that resolves — or rebinds after any one-shot check — to a
	/// reserved address. URLSession offers no hook into the resolution its
	/// connections actually use, so that gap is closed elsewhere: the https
	/// requirement means a listener at a reserved address must still present a
	/// valid certificate for the attacker's chosen name, and the OS
	/// local-network entitlement gates connections into private address space.
	package static func validate(
		endpoint: URL,
		policy: Atproto.DIDDocument.EndpointPolicy = .default
	) throws {
		let scheme = endpoint.scheme?.lowercased()
		//already strips the brackets around an IPv6 literal
		let host = endpoint.host(percentEncoded: false) ?? ""
		let exempt = policy.allowsInsecureLoopback && loopback(host: host)

		guard scheme == "https" || (exempt && scheme == "http") else {
			throw Atproto.DIDDocument.Errors
				.insecureServiceUrlScheme(endpoint.scheme)
		}

		guard permitted(host: host) || exempt else {
			throw Atproto.DIDDocument.Errors.disallowedServiceUrlHost(host)
		}
	}

	///the developer's own machine, which is narrower than the private ranges
	private static func loopback(host rawHost: String) -> Bool {
		let host = normalized(rawHost)

		if host == "localhost" || host.hasSuffix(".localhost") { return true }

		//same discipline as `permitted(host:)`: every parser that can read this
		//has to agree, or we don't know where the connection actually lands
		let v4Readings = [IPLiteral.v4(host), IPLiteral.legacyV4(host)]
			.compactMap { $0 }
		if !v4Readings.isEmpty {
			return v4Readings.allSatisfy { $0.first == 127 }
		}

		guard let v6 = IPLiteral.v6(host) else { return false }
		if let mapped = IPLiteral.embeddedV4(in: v6) {
			return mapped.first == 127
		}
		return v6.dropLast().allSatisfy { $0 == 0 } && v6[15] == 1
	}

	private static func normalized(_ rawHost: String) -> String {
		var host = rawHost.lowercased()
		//a trailing dot is the same name in FQDN form
		if host.hasSuffix(".") {
			host.removeLast()
		}
		//defensive: URL.host() unwraps these, URLComponents.host does not
		if host.hasPrefix("["), host.hasSuffix("]") {
			host = String(host.dropFirst().dropLast())
		}
		return host
	}

	static func permitted(host rawHost: String) -> Bool {
		let host = normalized(rawHost)

		guard !host.isEmpty else { return false }

		let v4 = IPLiteral.v4(host)
		let v6 = IPLiteral.v6(host)

		//One string can name different addresses depending on who parses it:
		//`0177.0.0.1` is 177.0.0.1 to IPLiteral.v4 and 127.0.0.1 to inet_aton,
		//and `010.0.0.1` splits the other way. We don't control which parser the
		//connection ultimately uses, so every reading has to be acceptable.
		if let v6, !permitted(v6: v6) { return false }
		if let v4, !permitted(v4: v4) { return false }
		if let legacy = IPLiteral.legacyV4(host), !permitted(v4: legacy) {
			return false
		}

		//An address literal that survived every parser's screening. Deliberately
		//v4/v6 only: a spelling only inet_aton reads earns no exemption — its
		//blocked readings were rejected above, and the rest fall through to the
		//name rules, which is how the resolver will treat the string wherever
		//its own inet_aton agrees it is not an address.
		if v4 != nil || v6 != nil { return true }

		//single-label names resolve through local search domains, never a public PDS
		guard let lastDot = host.lastIndex(of: ".") else { return false }

		return !reservedTLDs.contains(host[host.index(after: lastDot)...])
	}

	//special-use TLDs defined to name local or non-Internet hosts
	//(RFC 6761/6762, ICANN `.internal`); same list Bluesky's safe fetch rejects
	private static let reservedTLDs: Set<Substring> = [
		"localhost", "local", "internal", "test", "invalid", "example",
	]

	private static func permitted(v4 bytes: [UInt8]) -> Bool {
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

	private static func permitted(v6 bytes: [UInt8]) -> Bool {
		//::ffff:127.0.0.1 and friends are the v4 ranges wearing a v6 hat
		if let mapped = IPLiteral.embeddedV4(in: bytes) {
			return permitted(v4: mapped)
		}

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

}
