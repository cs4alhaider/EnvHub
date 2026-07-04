import ArgumentParser
import Foundation
import Core

/// `envhub store [--reveal]` — print the path to EnvHub's data store (the SwiftData
/// SQLite database), so you can back it up, inspect, or copy it. The app and CLI share
/// this one file.
struct Store: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Print the path to EnvHub's data store (for backup or inspection).")

    @Flag(help: "Also reveal the store in Finder.")
    var reveal = false

    func run() async throws {
        let url = EnvHubStore.storeURL
        // Just the path on stdout, so it composes: `cp \"$(envhub store)\" backup.store`
        print(url.path(percentEncoded: false))

        if reveal {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = ["-R", url.path(percentEncoded: false)]
            try? process.run()
            process.waitUntilExit()
        }
    }
}
