import ArgumentParser
import Foundation
import Core

/// `envhub open [path]` (also the bare `envhub .`) — open a folder in a project window
/// **without** adding it to EnvHub. Handy for a quick look; use `envhub add` to keep it
/// in the sidebar. Works even when the folder has no `.env` files yet.
struct Open: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Open a folder in a project window (without adding it to EnvHub).")

    @Argument(help: "Folder to open (default: current directory).")
    var path: String = "."

    func run() async throws {
        let folder = try requestApp(path, action: .openWindow)
        print("Opening \(ProjectStore.canonicalPath(for: folder)) in EnvHub…")
    }
}
