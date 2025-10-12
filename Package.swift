// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "apple-calendar-cli",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "apple-calendar", targets: ["AppleCalendarCLI"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AppleCalendarCLI",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("EventKit")
            ]
        )
    ]
)
