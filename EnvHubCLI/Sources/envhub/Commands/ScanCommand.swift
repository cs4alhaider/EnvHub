import ArgumentParser
import Foundation
import Core

/// `envhub scan [paths] [--deep]` — discover .env files, grouped by folder.
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
