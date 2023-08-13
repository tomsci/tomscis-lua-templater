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
                "TiltC",
                "Tilt",
            ]),
    ],
    dependencies: [],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "tilt-cli",
            dependencies: [
                "Tilt",
                "TiltC",
            ]),
        .target(
            name: "Tilt",
            dependencies: [
                "TiltC",
            ],
            resources: [
                .copy("src"),
            ]),
        .target(
            name: "TiltC",
            dependencies: [],
            exclude: [
                "src/ltests.c",
                "src/lua.c",
                "src/onelua.c",
                "src/testes",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .define("LUA_USE_POSIX"),
                .headerSearchPath("src"),
            ])
    ]
)
