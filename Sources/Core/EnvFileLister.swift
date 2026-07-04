import Foundation
import Scanner

/// Lists the `.env` files directly inside a folder. `.env*` files are hidden (dotfiles),
/// so we must NOT skip hidden files while enumerating. Matching (including skipping our
/// own `.bak` backups) is shared with the scanner via `EnvFileMatcher`.
public enum EnvFileLister {
    /// Whether a filename is an env file under the given patterns (and not a backup).
    public static func isEnvFileName(_ name: String, patterns: [String] = ScanConfig.defaultFilenamePatterns) -> Bool {
        EnvFileMatcher.matches(fileName: name, patterns: patterns)
    }

    /// The `.env` files directly inside `folder`, sorted by filename.
    public static func envFiles(in folder: URL, patterns: [String] = ScanConfig.defaultFilenamePatterns) -> [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: []                                   // do NOT skip hidden — .env is a dotfile
        ) else { return [] }

        return items
            .filter { EnvFileMatcher.matches(fileName: $0.lastPathComponent, patterns: patterns) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
