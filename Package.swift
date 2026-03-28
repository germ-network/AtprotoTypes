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
		)
	],
	dependencies: [
		.package(url: "https://github.com/Jarema/Base32.git", from: "0.10.2"),
		.package(
			url: "https://github.com/germ-network/GermConvenience.git",
			//			from: "0.0.2"
			branch: "mark/http-types"
		),
		.package(
			url: "https://github.com/apple/swift-crypto.git",
			.upToNextMajor(from: "4.2.0")),
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(
			name: "AtprotoTypes",
			dependencies: [
				"Base32",
				"GermConvenience",
				.product(name: "Crypto", package: "swift-crypto"),
			]
		),
		.testTarget(
			name: "AtprotoTypesTests",
			dependencies: ["AtprotoTypes"]
		),
	]
)
