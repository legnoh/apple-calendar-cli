// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "mcjs",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "mcjs", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor", from: "4.92.0"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.6")
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "Yams", package: "Yams")
            ],

            linkerSettings: [
                .linkedFramework("EventKit")
            ]
        )
    ]
)
