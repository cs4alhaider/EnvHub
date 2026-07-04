import ArgumentParser
import Foundation
import Core

/// `envhub import <file.envenc> [--into …] [--force] [--password-file …]` — decrypt a
/// `.envenc` and materialize its files into a folder.
struct Import: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Decrypt a .envenc and write its files.")

    @Argument(help: "The .envenc file to import.")
    var path: String

    @Option(help: "Destination folder (default: current directory).")
    var into: String = "."

    @Option(name: .customLong("password-file"), help: "Read the password from a file instead of prompting.")
    var passwordFile: String?

    @Flag(name: .shortAndLong, help: "Overwrite existing files.")
    var force = false

    func run() async throws {
        let password = try readPassword(passwordFile: passwordFile, confirm: false)
        let crypto = CryptoService()
        let data = try Data(contentsOf: fileURL(path))
        let export = try await crypto.decrypt(data, password: password)
        let written = try await crypto.materialize(export, into: fileURL(into), overwrite: force)
        for url in written {
            print("Wrote \(url.path(percentEncoded: false))")
        }
    }
}
