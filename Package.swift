// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "QueenfisherUltra",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "QueenfisherUltra",
            targets: ["QueenfisherUltra"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
		.package(url: "https://github.com/google/promises.git", from: "1.2.8"),
		.package(url: "https://github.com/adiwajshing/atomics.git", from: "1.0.0"),
		.package(url: "https://github.com/IBM-Swift/Swift-JWT.git", from: "3.6.0")
		
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "QueenfisherUltra",
			dependencies: [.product(name: "Promises", package: "Promises"),
						   .product(name: "SwiftJWT", package: "SwiftJWT"),
						   .product(name: "Atomics", package: "Atomics")]),
        .testTarget(
            name: "QueenfisherUltraTests",
            dependencies: ["QueenfisherUltra"]),
    ]
)
