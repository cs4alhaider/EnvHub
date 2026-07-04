import Foundation

/// One variable located in a project's env file — the unit of a cross-project search.
public struct IndexedVariable: Sendable, Hashable {
    public var projectID: UUID
    public var projectName: String
    public var projectPath: String
    public var fileURL: URL
    public var fileName: String
    public var kind: EnvKind
    public var key: String
    public var value: String

    public init(
        projectID: UUID, projectName: String, projectPath: String,
        fileURL: URL, fileName: String, kind: EnvKind, key: String, value: String
    ) {
        self.projectID = projectID
        self.projectName = projectName
        self.projectPath = projectPath
        self.fileURL = fileURL
        self.fileName = fileName
        self.kind = kind
        self.key = key
        self.value = value
    }
}

/// Search hits for one project, in display order — what the results list renders
/// as a section.
public struct ProjectSearchGroup: Identifiable, Sendable, Hashable {
    /// The project's ID (one group per project).
    public let id: UUID
    public let name: String
    public let path: String
    public let hits: [IndexedVariable]
}

/// Cross-project variable search. Operates on a prebuilt `SearchIndex` so it's pure,
/// fast (no I/O and no per-item lowercasing per keystroke), and unit-testable.
/// A query matches a variable's key, value, filename, or project name
/// (all case-insensitive, substring).
public enum ProjectSearch {
    /// All indexed variables matching `query`, in index order.
    public static func search(_ query: String, in index: SearchIndex) -> [IndexedVariable] {
        let q = normalized(query)
        guard !q.isEmpty else { return [] }
        var hits: [IndexedVariable] = []
        for (variable, haystack) in zip(index.variables, index.haystacks) where haystack.contains(q) {
            hits.append(variable)
        }
        return hits
    }

    /// Whether a project itself (by name or path) matches the query — used to keep a
    /// project visible in the sidebar even when none of its *variables* match.
    public static func projectMatches(query: String, name: String, path: String) -> Bool {
        let q = normalized(query)
        guard !q.isEmpty else { return false }
        return name.lowercased().contains(q) || path.lowercased().contains(q)
    }

    /// Groups hits by project (insertion order preserved within a group), sorted by
    /// project name for stable display.
    public static func groupedByProject(_ hits: [IndexedVariable]) -> [ProjectSearchGroup] {
        var order: [UUID] = []
        var byProject: [UUID: [IndexedVariable]] = [:]
        for hit in hits {
            if byProject[hit.projectID] == nil { order.append(hit.projectID) }
            byProject[hit.projectID, default: []].append(hit)
        }
        return order
            .compactMap { id -> ProjectSearchGroup? in
                guard let hits = byProject[id], let first = hits.first else { return nil }
                return ProjectSearchGroup(id: id, name: first.projectName, path: first.projectPath, hits: hits)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespaces).lowercased()
    }
}
