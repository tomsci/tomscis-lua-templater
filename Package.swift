// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "Tilt",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
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
                .plugin(name: "EmbedLuaPlugin", package: "LuaSwift")
            ]
        ),
        .testTarget(
            name: "tilt-test",
            dependencies: ["Tilt"],
            plugins: [
                .plugin(name: "EmbedLuaPlugin", package: "LuaSwift")
            ]
        )
    ]
)
