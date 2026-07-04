import ArgumentParser
import Foundation
import Core

/// `envhub list [project] [--mask] [--keys-only]` — list a project's env files and
/// variables.
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
