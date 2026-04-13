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
	],
	dependencies: [
		.package(url: "https://github.com/Jarema/Base32.git", from: "0.10.2"),
		.package(
			url: "https://github.com/germ-network/GermConvenience.git",
			from: "0.1.1"
		),
		.package(
			url: "https://github.com/apple/swift-crypto.git",
			.upToNextMajor(from: "4.2.0")),
		.package(url: "https://github.com/apple/swift-http-types.git", from: "1.5.1"),
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(
			name: "AtprotoTypes",
			dependencies: [
				"Base32",
				"GermConvenience",
				.product(name: "HTTPTypes", package: "swift-http-types"),
				.product(name: "Crypto", package: "swift-crypto"),
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
	]
)
