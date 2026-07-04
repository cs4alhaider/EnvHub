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

/// Cross-project variable search. Operates on a prebuilt in-memory index so it's pure,
/// fast (no I/O per keystroke), and unit-testable. A query matches a variable's key,
/// value, filename, or project name (all case-insensitive, substring).
public enum ProjectSearch {
    public static func search(_ query: String, in index: [IndexedVariable]) -> [IndexedVariable] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return index.filter {
            $0.key.lowercased().contains(q)
                || $0.value.lowercased().contains(q)
                || $0.fileName.lowercased().contains(q)
                || $0.projectName.lowercased().contains(q)
        }
    }
}
