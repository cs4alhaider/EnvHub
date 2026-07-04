import Foundation
import Model

/// Matches env filenames against glob-style patterns (`.env`, `.env.*`), while never
/// matching our own `.bak` backups.
public enum EnvFileMatcher {
    public static func isBackup(_ name: String) -> Bool { name.hasSuffix(".bak") }

    /// Convenience one-shot match. Compiles the patterns each call — fine for a single
    /// filename; use ``compile(_:)`` in loops.
    public static func matches(fileName name: String, patterns: [String]) -> Bool {
        compile(patterns).matches(name)
    }

    /// Compile glob patterns once so a scan or directory listing doesn't rebuild a
    /// regex per file. Invalid patterns are dropped (they simply never match).
    public static func compile(_ patterns: [String]) -> FilePatternMatcher {
        FilePatternMatcher(regexes: patterns.compactMap { pattern in
            guard !pattern.isEmpty else { return nil }
            return try? NSRegularExpression(pattern: regex(from: pattern), options: [.caseInsensitive])
        })
    }

    /// Translate a glob (`*` = any run, `?` = one char) into an anchored regex,
    /// escaping everything else literally.
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

/// Precompiled filename patterns, usable across the scanner's concurrent tasks.
/// `@unchecked Sendable` is sound here: `NSRegularExpression` is immutable and
/// documented thread-safe, and the array is `let`.
public struct FilePatternMatcher: @unchecked Sendable {
    let regexes: [NSRegularExpression]

    public func matches(_ name: String) -> Bool {
        guard !EnvFileMatcher.isBackup(name) else { return false }
        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        return regexes.contains { $0.firstMatch(in: name, options: [], range: range) != nil }
    }
}

/// Discovers `.env` files under one or more root folders.
///
/// The walk is **concurrent** (a bounded task group processes many directories in
/// parallel — directory enumeration on APFS parallelizes well, which is where the
/// speedup on big trees comes from), honors the directory exclusion list, skips
/// symlinked directories to avoid cycles, and groups results by parent folder.
///
/// It is also **cancellable mid-flight and keeps what it found**: on cancellation the
/// walk drains quickly and returns the results accumulated so far, so the UI can offer
/// "Stop & Review". Shallow scans (deepScan == false) look only at the roots' immediate
/// contents; deep scans recurse.
public enum EnvScanner {
    /// Minimum spacing between progress callbacks. Deep scans can visit hundreds of
    /// thousands of directories; emitting per-directory would flood the main actor
    /// with UI updates, so progress is throttled (the final totals always arrive).
    private static let progressInterval: Duration = .milliseconds(80)

    /// How many directories are enumerated concurrently. I/O-bound, so a bit above
    /// the core count is fine; capped to keep file-descriptor pressure sensible.
    private static var concurrentDirectories: Int {
        min(12, max(4, ProcessInfo.processInfo.activeProcessorCount))
    }

    /// What one concurrently-scanned directory contributes back to the coordinator.
    private struct DirectoryResult: Sendable {
        var directory: URL
        var envFiles: [URL] = []
        var subdirectories: [URL] = []
    }

    /// `@concurrent` — the filesystem walk always runs off the caller's actor;
    /// UI callers just `await` and stay responsive.
    @concurrent
    public static func scan(
        roots: [URL],
        config: ScanConfig,
        onProgress: (@Sendable (ScanProgress) -> Void)? = nil
    ) async -> [DiscoveredProject] {
        let exclusions = Set(config.exclusions)
        let matcher = EnvFileMatcher.compile(config.filenamePatterns)  // compile once per scan
        let deep = config.deepScan
        let width = concurrentDirectories
        let clock = ContinuousClock()

        var filesByFolder: [URL: [URL]] = [:]
        var visited = 0
        var found = 0
        var pending = roots
        var lastEmit: ContinuousClock.Instant?

        await withTaskGroup(of: DirectoryResult.self) { group in
            var inFlight = 0

            func launch(_ dir: URL) {
                inFlight += 1
                group.addTask {
                    scanDirectory(dir, matcher: matcher, exclusions: exclusions, deep: deep)
                }
            }

            while !pending.isEmpty || inFlight > 0 {
                // Keep the group topped up to `width` concurrent directories.
                while inFlight < width, !Task.isCancelled, let dir = pending.popLast() {
                    launch(dir)
                }
                guard let result = await group.next() else { break }
                inFlight -= 1
                visited += 1

                if !result.envFiles.isEmpty {
                    filesByFolder[result.directory, default: []].append(contentsOf: result.envFiles)
                    found += result.envFiles.count
                }
                pending.append(contentsOf: result.subdirectories)

                // Throttled progress: first update immediately, then at most one per interval.
                let now = clock.now
                if lastEmit == nil || now - lastEmit! >= progressInterval {
                    lastEmit = now
                    onProgress?(ScanProgress(
                        directoriesVisited: visited,
                        filesFound: found,
                        currentPath: result.directory.path(percentEncoded: false)
                    ))
                }

                if Task.isCancelled {
                    // Stop feeding new work; children notice cancellation themselves.
                    pending.removeAll()
                    group.cancelAll()
                }
            }
        }

        // Always emit the exact final totals (the throttle may have skipped them).
        onProgress?(ScanProgress(directoriesVisited: visited, filesFound: found, currentPath: nil))

        return filesByFolder
            .map { DiscoveredProject(folder: $0.key, files: $0.value.sorted { $0.lastPathComponent < $1.lastPathComponent }) }
            .sorted { $0.folder.path(percentEncoded: false) < $1.folder.path(percentEncoded: false) }
    }

    /// Enumerate a single directory: collect matching env files and (for deep scans)
    /// the non-excluded, non-symlink subdirectories to walk next.
    private static func scanDirectory(
        _ dir: URL,
        matcher: FilePatternMatcher,
        exclusions: Set<String>,
        deep: Bool
    ) -> DirectoryResult {
        var result = DirectoryResult(directory: dir)
        guard !Task.isCancelled,
              let entries = try? FileManager.default.contentsOfDirectory(
                  at: dir,
                  includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                  options: []                    // do NOT skip hidden — .env is a dotfile
              )
        else { return result }

        for entry in entries {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let isDir = values?.isDirectory ?? false
            let isSymlink = values?.isSymbolicLink ?? false

            if isDir {
                if deep, !isSymlink, !exclusions.contains(entry.lastPathComponent) {
                    result.subdirectories.append(entry)
                }
            } else if matcher.matches(entry.lastPathComponent) {
                result.envFiles.append(entry)
            }
        }
        return result
    }
}
