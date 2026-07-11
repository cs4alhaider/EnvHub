// swift-tools-version: 6.1
import PackageDescription

// envhub-cli — the `envhub` command-line tool, in its own package so the app's
// package (EnvHubKit, at the repo root) stays free of the executable target and
// the ArgumentParser dependency. It consumes EnvHubKit's `Core` product via a
// local path reference, so the app and CLI keep sharing one store schema and
// move in lockstep.
//
// Build:  swift build --package-path cli -c release --product envhub
// Run:    swift run  --package-path cli envhub --help

let concurrencySettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

let package = Package(
    name: "envhub-cli",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(name: "envhub", targets: ["envhub"]),
    ],
    dependencies: [
        .package(name: "EnvHubKit", path: ".."),
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
