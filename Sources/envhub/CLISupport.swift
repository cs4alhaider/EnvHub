import Foundation
import Darwin
import Core

// Small helpers shared by the subcommands in Commands/.

/// Resolve a CLI path argument (absolute or relative to the working directory).
func fileURL(_ path: String) -> URL { URL(fileURLWithPath: path) }

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

    var description: String {
        switch self {
        case .keyNotFound(let key): "key not found: \(key)"
        case .noPassword: "no password provided"
        case .passwordMismatch: "passwords did not match"
        case .workspaceNotFound(let name):
            "workspace not found: \(name) (see `envhub workspace list`; create one with `envhub workspace create`)"
        case .projectNotFound(let name):
            "project not found (by path or unique name): \(name)"
        }
    }
}
