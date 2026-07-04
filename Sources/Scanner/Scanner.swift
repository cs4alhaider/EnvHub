import Foundation
import Model

/// Matches env filenames against glob-style patterns (`.env`, `.env.*`), while never
/// matching our own `.bak` backups.
public enum EnvFileMatcher {
    public static func isBackup(_ name: String) -> Bool { name.hasSuffix(".bak") }

    public static func matches(fileName name: String, patterns: [String]) -> Bool {
        guard !isBackup(name) else { return false }
        return patterns.contains { glob(name, pattern: $0) }
    }

    static func glob(_ name: String, pattern: String) -> Bool {
        guard !pattern.isEmpty,
              let regex = try? NSRegularExpression(pattern: regex(from: pattern), options: [.caseInsensitive])
        else { return false }
        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        return regex.firstMatch(in: name, options: [], range: range) != nil
    }

    static func regex(from pattern: String) -> String {
        var rx = "^"
        for ch in pattern {
            switch ch {
            case "*": rx += ".*"
            case "?": rx += "."
            case ".", "(", ")", "[", "]", "{", "}", "+", "^", "$", "|", "\\", "/":
                rx += "\\" + String(ch)
            default: rx.append(ch)
            }
        }
        return rx + "$"
    }
}

/// Discovers `.env` files under one or more root folders. The walk is cooperative and
/// **cancellable** (checks `Task.isCancelled` and yields), honors the directory
/// exclusion list, skips symlinks to avoid cycles, and groups results by parent folder.
/// Shallow scans (deepScan == false) look only at the roots' immediate contents;
/// deep scans recurse.
public enum EnvScanner {
    public static func scan(
        roots: [URL],
        config: ScanConfig,
        onProgress: (@Sendable (ScanProgress) -> Void)? = nil
    ) async -> [DiscoveredProject] {
        let fm = FileManager.default
        let exclusions = Set(config.exclusions)
        var filesByFolder: [URL: [URL]] = [:]
        var visited = 0
        var found = 0
        var stack = roots

        while let dir = stack.popLast() {
            if Task.isCancelled { break }
            visited += 1

            guard let entries = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: []
            ) else { continue }

            for entry in entries {
                if Task.isCancelled { break }
                let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                let isDir = values?.isDirectory ?? false
                let isSymlink = values?.isSymbolicLink ?? false

                if isDir {
                    if config.deepScan, !isSymlink, !exclusions.contains(entry.lastPathComponent) {
                        stack.append(entry)
                    }
                } else if EnvFileMatcher.matches(fileName: entry.lastPathComponent, patterns: config.filenamePatterns) {
                    filesByFolder[dir, default: []].append(entry)
                    found += 1
                }
            }

            onProgress?(ScanProgress(
                directoriesVisited: visited,
                filesFound: found,
                currentPath: dir.path(percentEncoded: false)
            ))
            await Task.yield()
        }

        return filesByFolder
            .map { DiscoveredProject(folder: $0.key, files: $0.value.sorted { $0.lastPathComponent < $1.lastPathComponent }) }
            .sorted { $0.folder.path(percentEncoded: false) < $1.folder.path(percentEncoded: false) }
    }
}
