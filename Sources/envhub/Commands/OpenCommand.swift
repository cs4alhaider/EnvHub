import ArgumentParser
import Foundation
import Core

/// `envhub open [path]` (also the bare `envhub .`) — open a folder in the EnvHub app,
/// adding it as a project. Works even when the folder has no `.env` files yet: the app
/// lands on its create-a-file flow so you can add one and pick its type.
struct Open: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Open a folder in the EnvHub app (add it as a project).")

    @Argument(help: "Folder to open (default: current directory).")
    var path: String = "."

    /// The app's bundle identifier, used to launch/activate it.
    private static let bundleID = "net.alhaider.EnvHub"

    func run() async throws {
        let folder = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path(percentEncoded: false), isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw CLIError.notADirectory(path)
        }

        // Record the folder, then bring the app up — it consumes the request when it
        // activates (whether it was already running or just launched).
        try EnvHubStore.writePendingOpen(folder)
        guard launchApp() else { throw CLIError.appNotFound }
        print("Opening \(ProjectStore.canonicalPath(for: folder)) in EnvHub…")
    }

    /// Launch or activate the app via LaunchServices. Prefers the bundle id; falls
    /// back to the app name.
    private func launchApp() -> Bool {
        if run("/usr/bin/open", ["-b", Self.bundleID]) { return true }
        return run("/usr/bin/open", ["-a", "EnvHub"])
    }

    @discardableResult
    private func run(_ tool: String, _ args: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        do { try process.run() } catch { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
