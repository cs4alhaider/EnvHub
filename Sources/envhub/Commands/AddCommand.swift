import ArgumentParser
import Foundation
import Core

/// `envhub add [path]` — add a folder to EnvHub as a project (it appears in the
/// sidebar) and bring the app to it. Unlike `envhub open`, this persists the project.
/// Works even when the folder has no `.env` files yet: the app lands on its
/// create-a-file flow so you can add one and pick its type.
struct Add: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Add a folder to EnvHub as a project (shows in the sidebar).")

    @Argument(help: "Folder to add (default: current directory).")
    var path: String = "."

    func run() async throws {
        let folder = try requestApp(path, action: .addProject)
        print("Adding \(ProjectStore.canonicalPath(for: folder)) to EnvHub…")
    }
}
