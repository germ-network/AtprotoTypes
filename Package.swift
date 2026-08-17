// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "AtprotoTypes",
	platforms: [.iOS(.v16), .macOS(.v13)],
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.library(
			name: "AtprotoTypes",
			targets: ["AtprotoTypes"]
		),
		.library(name: "AtprotoTypesMocks", targets: ["AtprotoTypesMocks"]),
		.library(name: "Mockable", targets: ["Mockable"]),
		//CAR framing, DAG-CBOR, MST proof walking, CID recomputation and repo
		//commit-signature verification — additive, so a consumer that never
		//links it (e.g. an App Clip target) pays nothing for it existing.
		.library(name: "AtprotoTypesVerify", targets: ["AtprotoTypesVerify"]),
		.library(name: "AtprotoTypesVerifyMocks", targets: ["AtprotoTypesVerifyMocks"]),
	],
	dependencies: [
		.package(url: "https://github.com/swift-libp2p/swift-bases.git", from: "0.2.0"),
		.package(
			url: "https://github.com/germ-network/GermConvenience.git",
			from: "0.2.1"
		),
		.package(
			url: "https://github.com/apple/swift-crypto.git",
			.upToNextMajor(from: "4.2.0")
		),
		.package(url: "https://github.com/apple/swift-http-types.git", from: "1.5.1"),
		.package(url: "https://github.com/apple/swift-log", from: "1.6.0"),
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(
			name: "AtprotoTypes",
			dependencies: [
				"GermConvenience",
				.product(name: "Base32", package: "swift-bases"),
				.product(name: "Crypto", package: "swift-crypto"),
				.product(name: "HTTPTypes", package: "swift-http-types"),
				.product(name: "Logging", package: "swift-log"),
			]
		),
		.target(
			name: "Mockable",
			dependencies: []
		),
		.target(
			name: "AtprotoTypesMocks",
			dependencies: ["AtprotoTypes", "Mockable"]
		),
		.testTarget(
			name: "AtprotoTypesTests",
			dependencies: ["AtprotoTypes", "AtprotoTypesMocks", "Mockable"]
		),
		.target(
			name: "AtprotoTypesVerify",
			dependencies: [
				"AtprotoTypes",
				.product(name: "Crypto", package: "swift-crypto"),
				.product(name: "Base32", package: "swift-bases"),
				.product(name: "BaseX", package: "swift-bases"),
			]
		),
		//Fixture-building support for AtprotoTypesVerify — builds a real signed
		//commit over an MST over record blocks, so a consumer's tests can forge
		//one field and watch the proof fail for the reason it should, rather
		//than pinning captured bytes. A real library target, not test-target-
		//internal code, mirroring `AtprotoTypesMocks` alongside `AtprotoTypes`,
		//so it is usable from a different package's tests (`@testable import`
		//does not cross package boundaries).
		.target(
			name: "AtprotoTypesVerifyMocks",
			dependencies: [
				"AtprotoTypesVerify",
				"AtprotoTypes",
				.product(name: "Crypto", package: "swift-crypto"),
			]
		),
		.testTarget(
			name: "AtprotoTypesVerifyTests",
			dependencies: [
				"AtprotoTypesVerify",
				"AtprotoTypesVerifyMocks",
				"AtprotoTypes",
				.product(name: "Crypto", package: "swift-crypto"),
			]
		),
	]
)
