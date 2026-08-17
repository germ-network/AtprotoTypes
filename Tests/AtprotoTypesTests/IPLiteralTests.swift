//
//  IPLiteralTests.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 8/17/26.
//

import AtprotoTypes
import Testing

//`IPLiteral.v4` stands in for Network.framework's `IPv4Address`, which the
//package can no longer import on Linux or Android. These readings were taken
//from `IPv4Address` on macOS, so a drift in the reimplementation shows up here
//rather than as a hole in the endpoint screening.
struct IPLiteralTests {
	@Test(
		arguments: [
			("127.0.0.1", [127, 0, 0, 1]),
			("1.1.1.1", [1, 1, 1, 1]),
			("0.0.0.0", [0, 0, 0, 0]),
			("255.255.255.255", [255, 255, 255, 255]),
			//a leading zero is decimal here and octal to inet_aton
			("0177.0.0.1", [177, 0, 0, 1]),
			("010.0.0.1", [10, 0, 0, 1]),
			("01.02.03.04", [1, 2, 3, 4]),
			("00000000000000000177.0.0.1", [177, 0, 0, 1]),
			//fewer than four parts: the last one widens over what's left
			("16843009", [1, 1, 1, 1]),
			("2130706433", [127, 0, 0, 1]),
			("1", [0, 0, 0, 1]),
			("0.1", [0, 0, 0, 1]),
			("1.2", [1, 0, 0, 2]),
			("127.1", [127, 0, 0, 1]),
			("1.2.3", [1, 2, 0, 3]),
			//0x is hex in any position
			("0x7f000001", [127, 0, 0, 1]),
			("0xffffffff", [255, 255, 255, 255]),
			("0x7f.0.0.1", [127, 0, 0, 1]),
			("1.0xff", [1, 0, 0, 255]),
		] as [(String, [UInt8])]
	)
	func v4ReadsTheSpellingsIPv4AddressAccepted(
		_ host: String,
		_ expected: [UInt8]
	) {
		#expect(IPLiteral.v4(host) == expected)
	}

	@Test(
		arguments: [
			"", "localhost", "pds", "::1",
			//a trailing dot is a name in FQDN form
			"2130706433.", "192.168.1.1.",
			//empty parts, too many parts, a part that overflows its width
			".1.2.3", "1..2", "1.2.3.4.5", "300.1.2.3", "1.2.3.0x100",
			//UInt32(_:radix:) would take these; inet_aton and IPv4Address don't
			"+1.2.3.4", "-1", "0x",
		]
	)
	func v4RejectsWhatIsNotAnAddress(_ host: String) {
		#expect(IPLiteral.v4(host) == nil)
	}

	//the two IPv4 readings disagreeing is the whole point of consulting both
	@Test(
		arguments: [
			("0177.0.0.1", [177, 0, 0, 1], [127, 0, 0, 1]),
			("010.0.0.1", [10, 0, 0, 1], [8, 0, 0, 1]),
		] as [(String, [UInt8], [UInt8])]
	)
	func leadingZeroSplitsTheReadings(
		_ host: String,
		_ decimal: [UInt8],
		_ octal: [UInt8]
	) {
		#expect(IPLiteral.v4(host) == decimal)
		#expect(IPLiteral.legacyV4(host) == octal)
	}

	@Test func v6ParsesAndIgnoresTheZoneId() {
		#expect(IPLiteral.v6("::1") == [UInt8](repeating: 0, count: 15) + [1])
		#expect(IPLiteral.v6("fe80::1%en0") == IPLiteral.v6("fe80::1"))
		#expect(IPLiteral.v6("2606:4700:4700::1111")?.first == 0x26)
		#expect(IPLiteral.v6("localhost") == nil)
		#expect(IPLiteral.v6("127.0.0.1") == nil)
	}

	//`::` and `::1` are v6 addresses in their own right, not v4 spellings, and
	//the caller's v6 path is what rejects them
	@Test(
		arguments: [
			("::ffff:127.0.0.1", [127, 0, 0, 1] as [UInt8]?),
			("::ffff:10.0.0.5", [10, 0, 0, 5]),
			("::127.0.0.1", [127, 0, 0, 1]),
			("::1.1.1.1", [1, 1, 1, 1]),
			("::1", nil),
			("::", nil),
			("fd00::1", nil),
			("2606:4700:4700::1111", nil),
		] as [(String, [UInt8]?)]
	)
	func embeddedV4MatchesAsIPv4(_ host: String, _ expected: [UInt8]?) throws {
		let bytes = try #require(IPLiteral.v6(host))

		#expect(IPLiteral.embeddedV4(in: bytes) == expected)
	}
}
