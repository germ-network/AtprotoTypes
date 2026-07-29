//
//  PDSEndpointTests.swift
//  AtprotoTypes
//
//  Created by Mark @ Germ on 7/25/26.
//

import AtprotoTypes
import AtprotoTypesMocks
import Foundation
import Testing

struct PDSEndpointTests {

	private func document(endpoint: String) throws -> Atproto.DIDDocument {
		let base = try Atproto.DIDDocument.mock()
		let url = try #require(URL(string: endpoint))

		return .init(
			context: base.context,
			id: base.id,
			alsoKnownAs: base.alsoKnownAs,
			verificationMethod: base.verificationMethod,
			service: [
				.init(
					id: "#atproto_pds",
					type: "AtprotoPersonalDataServer",
					serviceEndpoint: url
				)
			]
		)
	}

	@Test(
		arguments: [
			"https://blusher.us-east.host.bsky.network",
			"https://pds.example.com:8443",
			"https://pds.example.com/some/prefix",
			//boundaries just outside the blocked ranges
			"https://172.32.0.1",
			"https://11.0.0.1",
			"https://100.128.0.1",
			"https://8.8.8.8",
			//dotless literals: only the address parsers can vouch for these,
			//the single-label rule would otherwise reject them
			"https://[2606:4700:4700::1111]",
			//1.1.1.1 to every parser we consult
			"https://16843009",
		]
	)
	func acceptsPublicHttpsEndpoints(_ endpoint: String) throws {
		#expect(try document(endpoint: endpoint).pdsUrl.absoluteString == endpoint)
	}

	@Test(
		arguments: [
			"http://pds.example.com",
			"file:///etc/passwd",
			"at://example.com",
		]
	)
	func rejectsNonHttpsSchemes(_ endpoint: String) throws {
		let document = try document(endpoint: endpoint)
		let scheme = URL(string: endpoint)?.scheme

		#expect(throws: Atproto.DIDDocument.Errors.insecureServiceUrlScheme(scheme)) {
			try document.pdsUrl
		}
	}

	@Test(
		arguments: [
			"https://localhost",
			"https://foo.localhost",
			"https://localhost.",
			"https://LOCALHOST",
			"https://127.0.0.1",
			"https://[::1]",
			"https://10.0.0.5",
			"https://192.168.1.1",
			"https://172.16.0.1",
			"https://169.254.169.254",
			"https://100.64.0.1",
			"https://[fd00::1]",
			"https://[fe80::1]",
			"https://[::ffff:127.0.0.1]",
			"https://0.0.0.0",
			//legacy inet_aton spellings of 127.0.0.1
			"https://2130706433",
			"https://0x7f000001",
			"https://0177.0.0.1",
		]
	)
	func rejectsLoopbackAndPrivateHosts(_ endpoint: String) throws {
		let document = try document(endpoint: endpoint)
		let host = try #require(URL(string: endpoint)?.host(percentEncoded: false))

		#expect(throws: Atproto.DIDDocument.Errors.disallowedServiceUrlHost(host)) {
			try document.pdsUrl
		}
	}

	@Test(
		arguments: [
			//single-label hosts resolve via local search domains
			"https://pds",
			"https://intranet",
			//special-use TLDs (RFC 6761/6762, ICANN .internal)
			"https://foo.local",
			"https://foo.internal",
			"https://foo.test",
			"https://foo.invalid",
			"https://foo.example",
			"https://FOO.INTERNAL",
			"https://foo.local.",
		]
	)
	func rejectsReservedNameSpace(_ endpoint: String) throws {
		let document = try document(endpoint: endpoint)
		let host = try #require(URL(string: endpoint)?.host(percentEncoded: false))

		#expect(throws: Atproto.DIDDocument.Errors.disallowedServiceUrlHost(host)) {
			try document.pdsUrl
		}
	}

	@Test(
		arguments: [
			//the dev-env default
			"http://localhost:2583",
			"http://127.0.0.1:2583",
			"https://localhost",
			"https://127.0.0.1",
			"https://[::1]",
			"http://foo.localhost",
			"https://[::ffff:127.0.0.1]",
		]
	)
	func developmentLoopbackAcceptsLocalPds(_ endpoint: String) throws {
		#expect(
			try document(endpoint: endpoint)
				.pdsUrl(policy: .developmentLoopback).absoluteString == endpoint
		)
	}

	//the hatch opens the local machine, not the local network, and not http at large
	@Test(
		arguments: [
			//http is forgiven only for loopback
			(
				"http://example.com",
				Atproto.DIDDocument.Errors.insecureServiceUrlScheme("http")
			),
			(
				"http://10.0.0.5",
				Atproto.DIDDocument.Errors.insecureServiceUrlScheme("http")
			),
			//https to a non-loopback host is exactly as strict as before
			(
				"https://10.0.0.5",
				Atproto.DIDDocument.Errors.disallowedServiceUrlHost("10.0.0.5")
			),
			(
				"https://192.168.1.1",
				Atproto.DIDDocument.Errors.disallowedServiceUrlHost("192.168.1.1")
			),
			(
				"https://169.254.169.254",
				Atproto.DIDDocument.Errors.disallowedServiceUrlHost(
					"169.254.169.254")
			),
			(
				"https://[fd00::1]",
				Atproto.DIDDocument.Errors.disallowedServiceUrlHost("fd00::1")
			),
			(
				"https://foo.internal",
				Atproto.DIDDocument.Errors.disallowedServiceUrlHost("foo.internal")
			),
			(
				"https://pds",
				Atproto.DIDDocument.Errors.disallowedServiceUrlHost("pds")
			),
			//IPv4Address reads 177.0.0.1 and inet_aton reads 127.0.0.1; a
			//disagreement earns no exemption
			(
				"https://0177.0.0.1",
				Atproto.DIDDocument.Errors.disallowedServiceUrlHost("0177.0.0.1")
			),
		]
	)
	func developmentLoopbackStillRejectsEverythingElse(
		_ endpoint: String,
		_ expected: Atproto.DIDDocument.Errors
	) throws {
		let document = try document(endpoint: endpoint)

		#expect(throws: expected) {
			try document.pdsUrl(policy: .developmentLoopback)
		}
	}

	@Test func defaultPolicyStillRejectsLoopback() throws {
		let document = try document(endpoint: "http://localhost:2583")

		#expect(throws: Atproto.DIDDocument.Errors.insecureServiceUrlScheme("http")) {
			try document.pdsUrl(policy: .default)
		}
		#expect(throws: Atproto.DIDDocument.Errors.insecureServiceUrlScheme("http")) {
			try document.pdsUrl
		}
	}

	@Test func checkServiceForAtprotoHonorsPolicy() throws {
		let document = try document(endpoint: "http://localhost:2583")

		#expect(
			try document.checkServiceForAtproto(policy: .developmentLoopback)
				.serviceEndpoint.host() == "localhost"
		)
		#expect(throws: Atproto.DIDDocument.Errors.insecureServiceUrlScheme("http")) {
			try document.checkServiceForAtproto()
		}
	}

	@Test func checkServiceForAtprotoRejectsDisallowedEndpoint() throws {
		let document = try document(endpoint: "https://127.0.0.1")

		#expect(throws: Atproto.DIDDocument.Errors.disallowedServiceUrlHost("127.0.0.1")) {
			try document.checkServiceForAtproto()
		}
	}

	@Test func checkServiceForAtprotoAcceptsPublicEndpoint() throws {
		let document = try document(endpoint: "https://pds.example.com")

		#expect(
			try document.checkServiceForAtproto().serviceEndpoint.host()
				== "pds.example.com")
	}

	//the mock is the fixture every other suite builds on, so it has to stay valid
	@Test func mockDocumentResolves() throws {
		#expect(
			try Atproto.DIDDocument.mock().pdsUrl
				== URL(string: "https://blusher.us-east.host.bsky.network")
		)
	}
}
