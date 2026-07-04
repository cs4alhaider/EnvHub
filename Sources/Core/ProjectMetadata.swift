import Foundation

/// Everything the project detail screen shows *about* a project's env files beyond
/// their contents: per-file variable counts, git status, and which filenames are
/// listed in the project's `.gitignore`. Loaded in one shot off the caller's actor
/// so the view never blocks on file reads or git spawns.
public struct ProjectMetadata: Sendable {
    /// Variable count per env-file URL (drives the tab and file-picker badges).
    public var variableCounts: [URL: Int]

    /// Git repo + per-file tracked/ignored status (drives the tracking warning banner).
    public var gitInfo: GitInfo

    /// Filenames (last path components) that appear as literal entries in the
    /// project folder's `.gitignore`.
    public var gitignoredFileNames: Set<String>

    public init(
        variableCounts: [URL: Int] = [:],
        gitInfo: GitInfo = GitInfo(isRepo: false, repoRoot: nil, statuses: []),
        gitignoredFileNames: Set<String> = []
    ) {
        self.variableCounts = variableCounts
        self.gitInfo = gitInfo
        self.gitignoredFileNames = gitignoredFileNames
    }

    /// The metadata to hold before the first load completes.
    public static let empty = ProjectMetadata()

    /// Loads metadata for a project folder and its env files.
    ///
    /// `@concurrent` — parses every file and runs (batched) git queries, so it always
    /// executes off the caller's actor. `files` are expected to be direct children of
    /// `folder` (which is what `ProjectLoader.envFiles` returns).
    @concurrent
    public static func load(folder: URL, files: [URL]) async -> ProjectMetadata {
        var counts: [URL: Int] = [:]
        for file in files {
            counts[file] = (try? EnvFileService.load(file))?.variables.count ?? 0
        }

        let info = await GitService.info(folder: folder, files: files)

        var ignoredNames: Set<String> = []
        if info.isRepo {
            let entries = GitService.gitignoreEntries(folder: folder)
            ignoredNames = Set(files.map(\.lastPathComponent).filter(entries.contains))
        }

        return ProjectMetadata(
            variableCounts: counts,
            gitInfo: info,
            gitignoredFileNames: ignoredNames
        )
    }
}
