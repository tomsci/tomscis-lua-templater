// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tilt",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Tilt",
            targets: [
                "Tilt",
            ]),
    ],
    dependencies: [
        .package(path: "LuaSwift"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "tilt-cli",
            dependencies: [
                "Tilt",
            ]),
        .target(
            name: "Tilt",
            dependencies: [
                .product(name: "Lua", package: "LuaSwift")
            ],
            resources: [
                .copy("src"),
            ]),
        // .testTarget(
        //     name: "tilt-test",
        //     dependencies: ["Tilt"]
        // )
    ]
)
