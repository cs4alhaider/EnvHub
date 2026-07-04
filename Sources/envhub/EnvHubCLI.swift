import ArgumentParser
import Core

/// `envhub` — the command-line companion to the EnvHub app. Every real operation lives
/// in `Core` and is shared with the app; each subcommand is a thin argument-parsing
/// shell in `Commands/`.
@main
struct EnvHub: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "envhub",
        abstract: "Discover and manage every .env file on your machine.",
        version: Core.version,
        subcommands: [Scan.self, List.self, Get.self, Export.self, Import.self, Workspace.self]
    )
}
