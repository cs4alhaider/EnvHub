import Foundation

/// A prebuilt, immutable index of every variable across every project, so that
/// per-keystroke search never touches the filesystem and never re-lowercases the
/// corpus (see `ProjectSearch.search`).
///
/// Build it off the caller's actor with ``build(projects:rules:patterns:)`` whenever
/// the set of projects (or the classification settings) changes.
public struct SearchIndex: Sendable {
    /// Every indexed variable, in project → file → line order.
    public let variables: [IndexedVariable]

    /// Env-file count per project ID — counts *files*, including ones with no
    /// variables, so sidebar badges stay accurate for empty files.
    public let fileCounts: [UUID: Int]

    /// One precomputed lowercase haystack per variable (key, value, filename, project
    /// name joined by newlines), aligned with `variables` by position.
    let haystacks: [String]

    public init(variables: [IndexedVariable], fileCounts: [UUID: Int] = [:]) {
        self.variables = variables
        self.fileCounts = fileCounts
        self.haystacks = variables.map {
            "\($0.key)\n\($0.value)\n\($0.fileName)\n\($0.projectName)".lowercased()
        }
    }

    /// The index to hold before the first build completes.
    public static let empty = SearchIndex(variables: [])

    /// Reads each project's env files once and builds the index.
    ///
    /// `@concurrent` — the filesystem walk and parsing always run off the caller's
    /// actor, so the UI can await this from the main actor without jank. Pass the
    /// *user's* classification rules and filename patterns (from settings) so the
    /// index agrees with what the rest of the app shows.
    @concurrent
    public static func build(
        projects: [Project],
        rules: [ClassificationRule],
        patterns: [String]
    ) async -> SearchIndex {
        var variables: [IndexedVariable] = []
        var fileCounts: [UUID: Int] = [:]

        for project in projects {
            let files = ProjectLoader.envFiles(in: project.path, rules: rules, patterns: patterns)
            fileCounts[project.id] = files.count
            let projectPath = project.path.path(percentEncoded: false)

            for file in files {
                guard let document = try? EnvFileService.load(file.path) else { continue }
                for variable in document.variables {
                    variables.append(IndexedVariable(
                        projectID: project.id,
                        projectName: project.name,
                        projectPath: projectPath,
                        fileURL: file.path,
                        fileName: file.fileName,
                        kind: file.kind,
                        key: variable.key,
                        value: variable.value
                    ))
                }
            }
        }
        return SearchIndex(variables: variables, fileCounts: fileCounts)
    }
}
