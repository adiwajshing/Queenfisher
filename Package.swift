// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "Queenfisher",
	platforms: [
		.macOS(.v10_15)
	],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(name: "Queenfisher", targets: ["Queenfisher"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
		.package(url: "https://github.com/vapor/jwt-kit", from: "4.0.0-rc.1"),
		.package(url: "https://github.com/swift-server/async-http-client.git", from: "1.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Queenfisher",
			dependencies: [.product(name: "JWTKit", package: "jwt-kit"),
						   .product(name: "AsyncHTTPClient", package: "async-http-client")]),
        .testTarget(
            name: "QueenfisherTests",
            dependencies: ["Queenfisher"]),
    ]
)
