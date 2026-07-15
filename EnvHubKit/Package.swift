// swift-tools-version: 6.1
import PackageDescription

// EnvHubKit — all UI-free logic (Model/Parser/Scanner/Classifier/Crypto/Core)
// and the SwiftUI dependency-injection glue (Helper).
// The macOS app (EnvHub/EnvHub.xcodeproj) links this package via a relative
// local-package reference (../EnvHubKit) and consumes the `Core` and `Helper` products.
// The `envhub` CLI lives in its own package at `EnvHubCLI/` and consumes `Core` the
// same way, so app and CLI share one store schema and move in lockstep.
//
// Dependency rules (kept clean on purpose):
//   • Concern modules (Parser/Scanner/Classifier/Crypto) depend ONLY on Model.
//   • Core is the facade that ties them together — consumed by both app and CLI.
//   • Helper is the only package target that imports SwiftUI, so the CLI never links it.

// Approachable-concurrency settings, matching the app target's
// SWIFT_APPROACHABLE_CONCURRENCY = YES. With `NonisolatedNonsendingByDefault`,
// a `nonisolated async` function runs on its *caller's* actor; anything that
// should leave the caller (filesystem walks, git spawns, scrypt) is explicitly
// marked `@concurrent`, so offloading is a visible decision at each declaration.
let concurrencySettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault")
]

let package = Package(
    name: "EnvHubKit",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Helper", targets: ["Helper"]),
    ],
    targets: [
        // MARK: Concern modules (depend only on Model)
        .target(name: "Model", swiftSettings: concurrencySettings),
        .target(name: "Parser", dependencies: ["Model"], swiftSettings: concurrencySettings),
        .target(name: "Scanner", dependencies: ["Model"], swiftSettings: concurrencySettings),
        .target(name: "Classifier", dependencies: ["Model"], swiftSettings: concurrencySettings),
        .target(name: "Crypto", dependencies: ["Model"], swiftSettings: concurrencySettings),

        // MARK: Facade + UI glue
        .target(
            name: "Core",
            dependencies: ["Model", "Parser", "Scanner", "Classifier", "Crypto"],
            swiftSettings: concurrencySettings
        ),
        .target(name: "Helper", dependencies: ["Core"], swiftSettings: concurrencySettings),

        // MARK: Tests (UI-free)
        .testTarget(name: "ModelTests", dependencies: ["Model"], swiftSettings: concurrencySettings),
        .testTarget(name: "ParserTests", dependencies: ["Parser", "Model"], swiftSettings: concurrencySettings),
        .testTarget(name: "ScannerTests", dependencies: ["Scanner", "Model"], swiftSettings: concurrencySettings),
        .testTarget(name: "ClassifierTests", dependencies: ["Classifier", "Model"], swiftSettings: concurrencySettings),
        .testTarget(name: "CryptoTests", dependencies: ["Crypto", "Model"], swiftSettings: concurrencySettings),
        .testTarget(name: "CoreTests", dependencies: ["Core"], swiftSettings: concurrencySettings),
    ]
)
