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
    public static func addProject(at url: URL, to context: ModelContext, workspaceID: UUID? = nil) -> ProjectRecord? {
        let path = canonicalPath(for: url)
        let existing = (try? context.fetch(FetchDescriptor<ProjectRecord>())) ?? []
        if existing.contains(where: { $0.path == path || canonicalPath(for: $0.url) == path }) { return nil }
        let record = ProjectRecord(name: url.lastPathComponent, path: path, workspaceID: workspaceID)
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

    /// One-time cleanup for stores that accumulated duplicates before paths were
    /// canonicalized (e.g. the same folder added with and without a trailing slash by
    /// successive scans). Keeps the oldest record per canonical path, merges pin /
    /// workspace metadata from the duplicates onto it, normalizes the stored path,
    /// and deletes the rest. Runs on every store open; a clean store is a no-op.
    public static func cleanupDuplicates(in context: ModelContext) {
        let all = ((try? context.fetch(FetchDescriptor<ProjectRecord>())) ?? [])
            .sorted { $0.dateAdded < $1.dateAdded }
        guard !all.isEmpty else { return }

        var keepers: [String: ProjectRecord] = [:]
        var deletedAny = false
        for project in all {
            let canonical = canonicalPath(for: project.url)
            if let keeper = keepers[canonical] {
                if project.isPinned { keeper.isPinned = true }
                if keeper.workspaceID == nil { keeper.workspaceID = project.workspaceID }
                context.delete(project)
                deletedAny = true
            } else {
                keepers[canonical] = project
                if project.path != canonical { project.path = canonical }
            }
        }
        if deletedAny || context.hasChanges {
            try? context.save()
        }
    }
}
