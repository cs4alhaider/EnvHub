import ArgumentParser
import Foundation
import Core

/// `envhub export <path> [--project] [--out …] [--password-file …]` — encrypt an env
/// file (or a whole project folder's env files) into a `.envenc`.
struct Export: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Encrypt an env file or project to .envenc.")

    @Argument(help: "Env file, or project folder with --project.")
    var path: String

    @Flag(help: "Export the whole project (all env files in the folder).")
    var project = false

    @Option(name: .shortAndLong, help: "Output .envenc path (default: <name>.envenc).")
    var out: String?

    @Option(name: .customLong("password-file"), help: "Read the password from a file instead of prompting.")
    var passwordFile: String?

    func run() async throws {
        let password = try readPassword(passwordFile: passwordFile, confirm: true)
        let source = fileURL(path)
        let crypto = CryptoService()

        let data: Data
        if project {
            let files = ProjectLoader.envFiles(in: source, rules: ClassificationRule.defaults)
            data = try await crypto.exportProject(name: source.lastPathComponent, files: files, password: password)
        } else {
            let kind = ProjectLoader.classify(fileName: source.lastPathComponent, rules: ClassificationRule.defaults)
            data = try await crypto.exportSingle(fileURL: source, kind: kind, password: password)
        }

        let outURL = fileURL(out ?? (source.lastPathComponent + ".envenc"))
        try data.write(to: outURL)
        print("Wrote \(outURL.path(percentEncoded: false))")
    }
}
