//
//  CommandLineTool.swift
//  EnvHub
//
//  Installs the `envhub` CLI that ships inside the app bundle (Contents/Helpers/envhub)
//  by symlinking it onto the user's PATH. Homebrew's cask does this automatically; this
//  is for people who download the app directly. In non-release builds the CLI isn't
//  bundled, so the action reports that cleanly.
//

import AppKit

enum CommandLineTool {
    /// The CLI shipped inside the app bundle, if present (release builds only).
    static var bundledURL: URL? {
        let url = Bundle.main.bundleURL.appending(path: "Contents/Helpers/envhub")
        return FileManager.default.isExecutableFile(atPath: url.path(percentEncoded: false)) ? url : nil
    }

    /// The first writable directory on PATH we'd symlink into (Homebrew bins first).
    private static var installDirectory: URL? {
        let candidates = ["/usr/local/bin", "/opt/homebrew/bin", "\(NSHomeDirectory())/.local/bin"]
        let fm = FileManager.default
        for path in candidates {
            if fm.isWritableFile(atPath: path) { return URL(filePath: path) }
            // ~/.local/bin may not exist yet — offer to create it.
            if path.hasSuffix("/.local/bin"), (try? fm.createDirectory(at: URL(filePath: path), withIntermediateDirectories: true)) != nil {
                return URL(filePath: path)
            }
        }
        return nil
    }

    /// Run the install and show an NSAlert with the outcome (user-initiated action).
    @MainActor
    static func installWithFeedback() {
        guard let source = bundledURL else {
            alert(
                title: "Command Line Tool Unavailable",
                message: "The envhub CLI is only bundled in release builds of EnvHub. Install it with Homebrew instead: brew install cs4alhaider/tap/envhub",
                style: .warning
            )
            return
        }

        let fm = FileManager.default
        guard let dir = installDirectory else {
            manualFallback(source: source)
            return
        }
        let dest = dir.appending(path: "envhub")
        do {
            if fm.fileExists(atPath: dest.path(percentEncoded: false)) {
                try fm.removeItem(at: dest)
            }
            try fm.createSymbolicLink(at: dest, withDestinationURL: source)
            alert(
                title: "Command Line Tool Installed",
                message: "You can now run “envhub” from the terminal.\n\nInstalled at \(dest.path(percentEncoded: false)).",
                style: .informational
            )
        } catch {
            manualFallback(source: source)
        }
    }

    @MainActor
    private static func manualFallback(source: URL) {
        let command = "sudo ln -sf \"\(source.path(percentEncoded: false))\" /usr/local/bin/envhub"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        alert(
            title: "Finish in Terminal",
            message: "EnvHub couldn't write to a directory on your PATH. The install command has been copied to your clipboard — paste it into Terminal:\n\n\(command)",
            style: .informational
        )
    }

    @MainActor
    private static func alert(title: String, message: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.runModal()
    }
}
