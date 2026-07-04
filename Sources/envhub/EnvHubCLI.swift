import ArgumentParser
import Foundation
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
        subcommands: [Scan.self, List.self, Get.self, Export.self, Import.self, Workspace.self, Open.self, Store.self]
    )

    /// Names ArgumentParser already routes to (subcommands + built-ins).
    private static let reservedNames: Set<String> = [
        "scan", "list", "get", "export", "import", "workspace", "open", "store",
        "help", "-h", "--help", "--version",
    ]

    /// Custom entry so `envhub .` (or `envhub ~/some/dir`) works like `code .`: a bare
    /// path first argument is rewritten to `envhub open <path>`. Anything that matches a
    /// subcommand, a flag, or a known option is left untouched.
    static func main() async {
        var arguments = Array(CommandLine.arguments.dropFirst())
        if let first = arguments.first,
           !reservedNames.contains(first),
           !first.hasPrefix("-") {
            arguments.insert("open", at: 0)
        }
        await main(arguments)
    }
}
