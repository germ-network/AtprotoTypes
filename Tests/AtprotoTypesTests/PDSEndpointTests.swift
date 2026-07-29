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
