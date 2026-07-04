// swift-tools-version: 6.1
import PackageDescription

// EnvHubKit — all UI-free logic (Model/Parser/Scanner/Classifier/Crypto/Core),
// the SwiftUI dependency-injection glue (Helper), and the `envhub` CLI.
// The macOS app (EnvHub/EnvHub.xcodeproj) links this package via a relative
// local-package reference (../) and consumes the `Core` and `Helper` products.
//
// Dependency rules (kept clean on purpose):
//   • Concern modules (Parser/Scanner/Classifier/Crypto) depend ONLY on Model.
//   • Core is the facade that ties them together — consumed by both app and CLI.
//   • Helper is the only package target that imports SwiftUI, so the CLI never links it.
let package = Package(
    name: "EnvHubKit",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Helper", targets: ["Helper"]),
        .executable(name: "envhub", targets: ["envhub"]),
    ],
    dependencies: [
        // Apple's standard CLI parser (chosen dependency policy: reputable deps allowed).
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        // MARK: Concern modules (depend only on Model)
        .target(name: "Model"),
        .target(name: "Parser", dependencies: ["Model"]),
        .target(name: "Scanner", dependencies: ["Model"]),
        .target(name: "Classifier", dependencies: ["Model"]),
        .target(name: "Crypto", dependencies: ["Model"]),

        // MARK: Facade + UI glue
        .target(
            name: "Core",
            dependencies: ["Model", "Parser", "Scanner", "Classifier", "Crypto"]
        ),
        .target(name: "Helper", dependencies: ["Core"]),

        // MARK: CLI (thin consumer of Core)
        .executableTarget(
            name: "envhub",
            dependencies: [
                "Core",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),

        // MARK: Tests (UI-free)
        .testTarget(name: "ModelTests", dependencies: ["Model"]),
        .testTarget(name: "ParserTests", dependencies: ["Parser", "Model"]),
        .testTarget(name: "ScannerTests", dependencies: ["Scanner", "Model"]),
        .testTarget(name: "ClassifierTests", dependencies: ["Classifier", "Model"]),
        .testTarget(name: "CryptoTests", dependencies: ["Crypto", "Model"]),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
    ]
)
