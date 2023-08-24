// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tilt",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Tilt",
            targets: [
                "Tilt",
            ]),
        .plugin(
            name: "EmbedLuaPlugin",
            targets: [
                "EmbedLuaPlugin"
            ]),
    ],
    dependencies: [
        .package(path: "LuaSwift"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.1.0"),
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
            plugins: [
                "EmbedLuaPlugin",
            ]),
        .testTarget(
            name: "tilt-test",
            dependencies: ["Tilt", "SourceModel"]
        ),
        .target(
            name: "SourceModel",
            dependencies: []),
        .executableTarget(
            name: "embedlua",
            dependencies: [
                "SourceModel",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .plugin(
            name: "EmbedLuaPlugin",
            capability: .buildTool(),
            dependencies: [
                "embedlua",
            ]),
    ]
)
