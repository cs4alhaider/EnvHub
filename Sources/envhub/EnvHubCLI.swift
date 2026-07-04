import ArgumentParser
import Foundation
import Darwin
import Core

/// `envhub` — the command-line companion to the EnvHub app. Every real operation lives
/// in `Core` and is shared with the app.
@main
struct EnvHub: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "envhub",
        abstract: "Discover and manage every .env file on your machine.",
        version: Core.version,
        subcommands: [Scan.self, List.self, Get.self, Export.self, Import.self]
    )
}

// MARK: - scan

struct Scan: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Discover .env files, grouped by folder.")

    @Argument(help: "Folders to scan (default: current directory).")
    var paths: [String] = ["."]

    @Flag(name: .shortAndLong, help: "Recurse into subfolders.")
    var deep = false

    func run() async throws {
        var config = ScanConfig.default
        config.deepScan = deep
        let projects = await ScanService().scan(roots: paths.map(fileURL), config: config)

        if projects.isEmpty {
            print("No .env files found.")
            return
        }
        for project in projects {
            print(project.folder.path(percentEncoded: false))
            for file in project.files {
                print("  \(file.lastPathComponent)")
            }
        }
    }
}

// MARK: - list

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "List a project's env files and variables.")

    @Argument(help: "Project folder (default: current directory).")
    var project: String = "."

    @Flag(help: "Mask values.")
    var mask = false

    @Flag(name: .customLong("keys-only"), help: "Print only keys.")
    var keysOnly = false

    func run() throws {
        let files = ProjectLoader.envFiles(in: fileURL(project), rules: ClassificationRule.defaults)
        guard !files.isEmpty else {
            print("No .env files in \(fileURL(project).path(percentEncoded: false))")
            return
        }
        for file in files {
            print("\(file.fileName)  [\(file.kind.title)]")
            let doc = try EnvFileService.load(file.path)
            for variable in doc.variables {
                if keysOnly {
                    print("  \(variable.key)")
                } else {
                    print("  \(variable.key)=\(display(variable.value, mask: mask))")
                }
            }
        }
    }
}

// MARK: - get

struct Get: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Print a single key's value.")

    @Argument(help: "The variable name.")
    var key: String

    @Option(help: "Read from a specific .env file.")
    var file: String?

    @Option(help: "Search a project folder's env files.")
    var project: String?

    @Flag(help: "Return a masked value.")
    var mask = false

    func run() throws {
        let urls: [URL]
        if let file {
            urls = [fileURL(file)]
        } else if let project {
            urls = ProjectLoader.envFiles(in: fileURL(project), rules: ClassificationRule.defaults).map(\.path)
        } else {
            urls = ProjectLoader.envFiles(in: fileURL("."), rules: ClassificationRule.defaults).map(\.path)
        }

        for url in urls {
            let doc = try EnvFileService.load(url)
            if let variable = doc.variables.first(where: { $0.key == key }) {
                print(display(variable.value, mask: mask))
                return
            }
        }
        throw CLIError.keyNotFound(key)
    }
}

// MARK: - export

struct Export: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Encrypt an env file or project to .envenc.")

    @Argument(help: "Env file, or project folder with --project.")
    var path: String

    @Flag(help: "Export the whole project (all env files in the folder).")
    var project = false

    @Option(name: .shortAndLong, help: "Output .envenc path (default: <name>.envenc).")
    var out: String?

    @Option(name: .customLong("password-file"), help: "Read the password from a file instead of prompting.")
    var passwordFile: String?

    func run() throws {
        let password = try readPassword(passwordFile: passwordFile, confirm: true)
        let source = fileURL(path)
        let crypto = CryptoService()

        let data: Data
        if project {
            let files = ProjectLoader.envFiles(in: source, rules: ClassificationRule.defaults)
            data = try crypto.exportProject(name: source.lastPathComponent, files: files, password: password)
        } else {
            let kind = ProjectLoader.classify(fileName: source.lastPathComponent, rules: ClassificationRule.defaults)
            data = try crypto.exportSingle(fileURL: source, kind: kind, password: password)
        }

        let outURL = fileURL(out ?? (source.lastPathComponent + ".envenc"))
        try data.write(to: outURL)
        print("Wrote \(outURL.path(percentEncoded: false))")
    }
}

// MARK: - import

struct Import: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Decrypt a .envenc and write its files.")

    @Argument(help: "The .envenc file to import.")
    var path: String

    @Option(help: "Destination folder (default: current directory).")
    var into: String = "."

    @Option(name: .customLong("password-file"), help: "Read the password from a file instead of prompting.")
    var passwordFile: String?

    @Flag(name: .shortAndLong, help: "Overwrite existing files.")
    var force = false

    func run() throws {
        let password = try readPassword(passwordFile: passwordFile, confirm: false)
        let crypto = CryptoService()
        let data = try Data(contentsOf: fileURL(path))
        let export = try crypto.decrypt(data, password: password)
        let written = try crypto.materialize(export, into: fileURL(into), overwrite: force)
        for url in written {
            print("Wrote \(url.path(percentEncoded: false))")
        }
    }
}

// MARK: - Helpers

private func fileURL(_ path: String) -> URL { URL(fileURLWithPath: path) }

private func display(_ value: String, mask: Bool) -> String {
    guard mask else { return value }
    return value.isEmpty ? "" : String(repeating: "•", count: min(max(value.count, 3), 8))
}

private func readPassword(passwordFile: String?, confirm: Bool) throws -> String {
    if let passwordFile {
        let content = try String(contentsOf: fileURL(passwordFile), encoding: .utf8)
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    guard let raw = getpass("Password: ") else { throw CLIError.noPassword }
    let password = String(cString: raw)
    if confirm {
        guard let raw2 = getpass("Confirm password: ") else { throw CLIError.noPassword }
        guard String(cString: raw2) == password else { throw CLIError.passwordMismatch }
    }
    return password
}

enum CLIError: Error, CustomStringConvertible {
    case keyNotFound(String)
    case noPassword
    case passwordMismatch

    var description: String {
        switch self {
        case .keyNotFound(let key): "key not found: \(key)"
        case .noPassword: "no password provided"
        case .passwordMismatch: "passwords did not match"
        }
    }
}
