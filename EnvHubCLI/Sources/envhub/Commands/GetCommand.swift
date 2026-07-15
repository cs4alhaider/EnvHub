import ArgumentParser
import Foundation
import Core

/// `envhub get KEY [--file …|--project …] [--mask]` — print a single key's value.
/// Searches the given file, or every env file of a project folder, first match wins.
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
