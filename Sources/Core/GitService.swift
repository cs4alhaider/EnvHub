import Foundation

/// Thin wrapper over the `git` CLI (the app is non-sandboxed, so shelling out is fine).
/// Used to warn when `.env` files are tracked by git and to manage `.gitignore`.
public enum GitService {
    @discardableResult
    static func git(_ args: [String], in dir: URL) -> (status: Int32, out: String, err: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = dir
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        do { try process.run() } catch { return (-1, "", "\(error)") }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus,
                String(decoding: outData, as: UTF8.self),
                String(decoding: errData, as: UTF8.self))
    }

    // MARK: Status

    public static func repoRoot(for folder: URL) -> URL? {
        let result = git(["rev-parse", "--show-toplevel"], in: folder)
        guard result.status == 0 else { return nil }
        let path = result.out.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    public static func isTracked(_ file: URL, in folder: URL) -> Bool {
        git(["ls-files", "--error-unmatch", "--", file.path(percentEncoded: false)], in: folder).status == 0
    }

    public static func isIgnored(_ file: URL, in folder: URL) -> Bool {
        git(["check-ignore", "-q", "--", file.path(percentEncoded: false)], in: folder).status == 0
    }

    public static func info(folder: URL, files: [URL]) -> GitInfo {
        guard let root = repoRoot(for: folder) else {
            return GitInfo(isRepo: false, repoRoot: nil, statuses: [])
        }
        let statuses = files.map {
            GitFileStatus(url: $0, isTracked: isTracked($0, in: folder), isIgnored: isIgnored($0, in: folder))
        }
        return GitInfo(isRepo: true, repoRoot: root, statuses: statuses)
    }

    // MARK: Mutations

    /// Untrack a file (`git rm --cached`) — the working file stays on disk.
    @discardableResult
    public static func untrack(_ file: URL, in folder: URL) -> Bool {
        git(["rm", "--cached", "--", file.path(percentEncoded: false)], in: folder).status == 0
    }

    /// Untrack the file and add its name to the project's `.gitignore`.
    public static func unstageAndIgnore(_ file: URL, in folder: URL) throws {
        untrack(file, in: folder)
        try addToGitignore(file.lastPathComponent, folder: folder)
    }

    // MARK: .gitignore (project-folder-local)

    public static func gitignoreURL(for folder: URL) -> URL {
        folder.appendingPathComponent(".gitignore")
    }

    public static func gitignoreLines(folder: URL) -> [String] {
        guard let content = try? String(contentsOf: gitignoreURL(for: folder), encoding: .utf8) else { return [] }
        return content.components(separatedBy: "\n")
    }

    public static func isInGitignore(_ pattern: String, folder: URL) -> Bool {
        gitignoreLines(folder: folder).contains { $0.trimmingCharacters(in: .whitespaces) == pattern }
    }

    public static func addToGitignore(_ pattern: String, folder: URL) throws {
        guard !isInGitignore(pattern, folder: folder) else { return }
        let url = gitignoreURL(for: folder)
        var content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        if !content.isEmpty && !content.hasSuffix("\n") { content += "\n" }
        content += pattern + "\n"
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    public static func removeFromGitignore(_ pattern: String, folder: URL) throws {
        let url = gitignoreURL(for: folder)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let kept = content
            .components(separatedBy: "\n")
            .filter { $0.trimmingCharacters(in: .whitespaces) != pattern }
        try kept.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
