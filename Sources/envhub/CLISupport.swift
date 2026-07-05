import Foundation
import Darwin
import Core

// Small helpers shared by the subcommands in Commands/.

/// Resolve a CLI path argument (absolute or relative to the working directory).
func fileURL(_ path: String) -> URL { URL(fileURLWithPath: path) }

/// Validate a folder path, record a pending request for the app, and bring the app up.
/// Shared by `envhub add` (adds the project) and `envhub open` / `envhub .` (opens a
/// window without adding). Returns the resolved folder URL.
@discardableResult
func requestApp(_ path: String, action: EnvHubStore.PendingAction) throws -> URL {
    let folder = fileURL(path)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: folder.path(percentEncoded: false), isDirectory: &isDirectory),
          isDirectory.boolValue else {
        throw CLIError.notADirectory(path)
    }
    try EnvHubStore.writePendingOpen(folder, action: action)
    guard launchEnvHubApp() else { throw CLIError.appNotFound }
    return folder
}

/// Launch or activate the EnvHub app via LaunchServices (bundle id, then app name).
private func launchEnvHubApp() -> Bool {
    if runTool("/usr/bin/open", ["-b", "net.alhaider.EnvHub"]) { return true }
    return runTool("/usr/bin/open", ["-a", "EnvHub"])
}

private func runTool(_ tool: String, _ args: [String]) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool)
    process.arguments = args
    do { try process.run() } catch { return false }
    process.waitUntilExit()
    return process.terminationStatus == 0
}

/// A value for terminal output, masked when `--mask` is set (short dot cap — CLI
/// output is denser than the app's table).
func display(_ value: String, mask: Bool) -> String {
    mask ? ValueMasking.masked(value, maxDots: 8) : value
}

/// Read the password from `--password-file` when given, otherwise prompt on the TTY
/// without echoing (via `getpass`). `confirm` re-prompts and compares — used for
/// export, where a typo'd password would create an undecryptable file.
func readPassword(passwordFile: String?, confirm: Bool) throws -> String {
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
    case workspaceNotFound(String)
    case projectNotFound(String)
    case notADirectory(String)
    case appNotFound

    var description: String {
        switch self {
        case .keyNotFound(let key): "key not found: \(key)"
        case .noPassword: "no password provided"
        case .passwordMismatch: "passwords did not match"
        case .workspaceNotFound(let name):
            "workspace not found: \(name) (see `envhub workspace list`; create one with `envhub workspace create`)"
        case .projectNotFound(let name):
            "project not found (by path or unique name): \(name)"
        case .notADirectory(let path):
            "not a folder: \(path)"
        case .appNotFound:
            "couldn't launch the EnvHub app — build/run it once so macOS knows where it is"
        }
    }
}
