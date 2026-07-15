// swift-tools-version: 6.1
import PackageDescription

// EnvHubCLI — the `envhub` command-line tool, in its own package so the app's
// package (EnvHubKit/) stays free of the executable target and the
// ArgumentParser dependency. It consumes EnvHubKit's `Core` product via a
// local path reference, so the app and CLI keep sharing one store schema and
// move in lockstep.
//
// Build:  swift build --package-path EnvHubCLI -c release --product envhub
// Run:    swift run  --package-path EnvHubCLI envhub --help

let concurrencySettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

let package = Package(
    name: "EnvHubCLI",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "envhub", targets: ["envhub"]),
    ],
    dependencies: [
        .package(name: "EnvHubKit", path: "../EnvHubKit"),
        // Apple's standard CLI parser (dependency policy: reputable deps only).
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "envhub",
            dependencies: [
                .product(name: "Core", package: "EnvHubKit"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: concurrencySettings
        ),
    ]
)
