import Foundation

/// Thin wrapper over the `git` CLI. Used to warn when `.env` files are tracked by
/// git and to manage `.gitignore`.
///
/// Sandbox-aware: the App Store edition can't reliably spawn system git, so inside
/// the sandbox every spawn is disabled — repo *detection* stays (filesystem-based)
/// and all `.gitignore` management stays (plain file I/O); only tracked/ignored
/// detection and `untrack` degrade, which hides the tracking banner in that edition.
///
/// Every public entry point is `@concurrent async`: each one spawns a process or
/// touches the filesystem, so it must never run on the caller's actor (the app calls
/// these from the main actor). The private helpers stay synchronous — they only ever
/// execute inside one of the public functions, already off-actor.
public enum GitService {
    /// Runs `git` with `args` in `dir`, capturing exit status and output. `stdin`
    /// (when given) is written to the process and closed — used by the batched
    /// `check-ignore --stdin` query. Internal (not private) so tests can drive
    /// fixture repos with it.
    @discardableResult
    static func git(_ args: [String], in dir: URL, stdin: Data? = nil) -> (status: Int32, out: String, err: String) {
        guard !AppSandbox.isActive else {
            return (-1, "", "git integration is disabled in the sandboxed edition")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = dir
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        let inPipe = stdin.map { _ in Pipe() }
        if let inPipe { process.standardInput = inPipe }
        do { try process.run() } catch { return (-1, "", "\(error)") }
        if let inPipe, let stdin {
            inPipe.fileHandleForWriting.write(stdin)
            try? inPipe.fileHandleForWriting.close()
        }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus,
                String(decoding: outData, as: UTF8.self),
                String(decoding: errData, as: UTF8.self))
    }

    // MARK: Status

    /// The repository root containing `folder`, or `nil` when it isn't inside a repo.
    @concurrent
    public static func repoRoot(for folder: URL) async -> URL? {
        findRepoRoot(for: folder)
    }

    /// Whether `file` is tracked by git (in the index or committed) — the secret-leak
    /// signal the app warns about.
    @concurrent
    public static func isTracked(_ file: URL, in folder: URL) async -> Bool {
        git(["ls-files", "--error-unmatch", "--", file.path(percentEncoded: false)], in: folder).status == 0
    }

    /// Whether `file` is matched by any ignore rule.
    @concurrent
    public static func isIgnored(_ file: URL, in folder: URL) async -> Bool {
        git(["check-ignore", "-q", "--", file.path(percentEncoded: false)], in: folder).status == 0
    }

    /// Repo + per-file status for a project's env files, in three `git` spawns total
    /// (`rev-parse` + one batched `ls-files` + one batched `check-ignore`) instead of
    /// one per file per question.
    ///
    /// `files` must be direct children of `folder` — their filenames are used as
    /// pathspecs relative to it (which is how the rest of EnvHub produces them).
    @concurrent
    public static func info(folder: URL, files: [URL]) async -> GitInfo {
        guard let root = findRepoRoot(for: folder) else {
            return GitInfo(isRepo: false, repoRoot: nil, statuses: [])
        }
        // Sandboxed: repo detection only — no per-file status, so callers never
        // show tracking warnings they couldn't act on (untrack needs git too).
        guard !AppSandbox.isActive else {
            return GitInfo(isRepo: true, repoRoot: root, statuses: [])
        }
        let names = files.map(\.lastPathComponent)
        let tracked = trackedNames(in: folder, names: names)
        let ignored = ignoredNames(in: folder, names: names)
        let statuses = files.map {
            GitFileStatus(
                url: $0,
                isTracked: tracked.contains($0.lastPathComponent),
                isIgnored: ignored.contains($0.lastPathComponent)
            )
        }
        return GitInfo(isRepo: true, repoRoot: root, statuses: statuses)
    }

    // MARK: Mutations

    /// Untrack a file (`git rm --cached`) — the working file stays on disk.
    @concurrent
    @discardableResult
    public static func untrack(_ file: URL, in folder: URL) async -> Bool {
        git(["rm", "--cached", "--", file.path(percentEncoded: false)], in: folder).status == 0
    }

    /// Untrack the file and add its name to the project's `.gitignore` — the one-click
    /// remedy behind the tracking warning banner.
    @concurrent
    public static func unstageAndIgnore(_ file: URL, in folder: URL) async throws {
        git(["rm", "--cached", "--", file.path(percentEncoded: false)], in: folder)
        try appendToGitignore(file.lastPathComponent, folder: folder)
    }

    // MARK: .gitignore (project-folder-local)

    /// The `.gitignore` EnvHub manages: the one directly in the project folder.
    public static func gitignoreURL(for folder: URL) -> URL {
        folder.appendingPathComponent(".gitignore")
    }

    /// Whether `pattern` appears as a literal line in the folder's `.gitignore`.
    @concurrent
    public static func isInGitignore(_ pattern: String, folder: URL) async -> Bool {
        gitignoreEntries(folder: folder).contains(pattern)
    }

    /// Appends `pattern` as its own line (no-op if already present).
    @concurrent
    public static func addToGitignore(_ pattern: String, folder: URL) async throws {
        try appendToGitignore(pattern, folder: folder)
    }

    /// Removes any line that is exactly `pattern` (after trimming).
    @concurrent
    public static func removeFromGitignore(_ pattern: String, folder: URL) async throws {
        let url = gitignoreURL(for: folder)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let kept = content
            .components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces) != pattern }
        try kept.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Synchronous internals (only ever called off-actor, from the above)

    private static func findRepoRoot(for folder: URL) -> URL? {
        let result = git(["rev-parse", "--show-toplevel"], in: folder)
        guard result.status == 0 else { return nil }
        let path = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    /// The subset of `names` that git tracks, via one `ls-files` spawn.
    /// (`-z` NUL-separates output so filenames with spaces round-trip.)
    private static func trackedNames(in folder: URL, names: [String]) -> Set<String> {
        guard !names.isEmpty else { return [] }
        let result = git(["ls-files", "-z", "--"] + names, in: folder)
        guard result.status == 0 else { return [] }
        return Set(result.out.split(separator: "\0").map(String.init))
    }

    /// The subset of `names` that git ignores, via one `check-ignore` spawn.
    /// git only allows `-z` (NUL-separated, unquoted output) together with `--stdin`,
    /// so the names go in on stdin. Exit status 1 just means "none ignored", so only
    /// the output matters.
    private static func ignoredNames(in folder: URL, names: [String]) -> Set<String> {
        guard !names.isEmpty else { return [] }
        let input = Data((names.joined(separator: "\0") + "\0").utf8)
        let result = git(["check-ignore", "-z", "--stdin"], in: folder, stdin: input)
        return Set(result.out.split(separator: "\0").map(String.init))
    }

    /// The trimmed, non-empty lines of the folder's `.gitignore`.
    /// Internal so `ProjectMetadata.load` can reuse one read for many filenames.
    static func gitignoreEntries(folder: URL) -> Set<String> {
        guard let content = try? String(contentsOf: gitignoreURL(for: folder), encoding: .utf8) else { return [] }
        return Set(
            content
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )
    }

    private static func appendToGitignore(_ pattern: String, folder: URL) throws {
        guard !gitignoreEntries(folder: folder).contains(pattern) else { return }
        let url = gitignoreURL(for: folder)
        var content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        if !content.isEmpty && !content.hasSuffix("\n") { content += "\n" }
        content += pattern + "\n"
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
