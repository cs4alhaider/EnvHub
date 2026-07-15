import Foundation
import SwiftData

/// Project operations kept out of the views (business logic lives in the package).
public enum ProjectStore {
    /// The canonical identity of a project folder: standardized, symlinks resolved,
    /// no trailing slash. Two URLs that spell the same folder differently (trailing
    /// slash, `/tmp` vs `/private/tmp`, `..` segments) canonicalize to the same
    /// string — this is what duplicate detection compares, and what gets stored.
    public static func canonicalPath(for url: URL) -> String {
        var path = url.standardizedFileURL.resolvingSymlinksInPath().path(percentEncoded: false)
        while path.count > 1 && path.hasSuffix("/") { path.removeLast() }
        return path
    }

    /// Adds a folder as a project, ignoring duplicates by **canonical** path. Never
    /// modifies disk. `workspaceID` places the new project into a workspace section
    /// (nil = "Others"). Like `WorkspaceStore`, not actor-bound — runs wherever the
    /// passed context lives.
    @discardableResult
    public static func addProject(
        at url: URL,
        to context: ModelContext,
        workspaceID: UUID? = nil,
        bookmark: Data? = nil
    ) -> ProjectRecord? {
        let path = canonicalPath(for: url)
        let existing = (try? context.fetch(FetchDescriptor<ProjectRecord>())) ?? []
        if let match = existing.first(where: { $0.path == path || canonicalPath(for: $0.url) == path }) {
            // Re-adding an existing project with a fresh grant updates its bookmark
            // (the sandboxed edition's re-grant path).
            if let bookmark { match.bookmarkData = bookmark }
            return nil
        }
        let record = ProjectRecord(
            name: url.lastPathComponent, path: path, workspaceID: workspaceID, bookmarkData: bookmark)
        context.insert(record)
        return record
    }

    /// Forgets a project in the app. Files on disk are untouched.
    public static func remove(_ record: ProjectRecord, from context: ModelContext) {
        context.delete(record)
    }

    /// Forgets **every** project (Settings → Data). Workspaces, scan folders, and
    /// preferences survive; nothing on disk is touched.
    public static func removeAll(in context: ModelContext) {
        for record in (try? context.fetch(FetchDescriptor<ProjectRecord>())) ?? [] {
            context.delete(record)
        }
    }

    /// Pin or unpin a project (pinned projects surface in the Pinned section).
    public static func setPinned(_ record: ProjectRecord, _ pinned: Bool) {
        record.isPinned = pinned
    }
}
