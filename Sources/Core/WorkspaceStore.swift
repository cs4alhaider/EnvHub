import Foundation
import SwiftData

/// How `WorkspaceStore.sortProjects` orders a section's projects.
public enum ProjectSortKey: String, CaseIterable, Sendable {
    case name
    case path
    /// Most recently added first.
    case date
}

/// Workspace (sidebar section) operations, shared by the app and the CLI — both open
/// the same store (see `EnvHubStore.storeURL`), so a workspace created on either side
/// shows up on the other.
///
/// Functions are deliberately **not** actor-bound: they run wherever the `ModelContext`
/// you pass lives (the app hands in its main-actor context; the CLI a context of its
/// own). Callers own the context's threading; mutating callers own saving.
public enum WorkspaceStore {
    // MARK: Queries

    /// All workspaces in display order (manual order, then name).
    public static func all(in context: ModelContext) -> [WorkspaceRecord] {
        orderedWorkspaces((try? context.fetch(FetchDescriptor<WorkspaceRecord>())) ?? [])
    }

    /// Display order for an already-fetched workspace list (manual order, then name) —
    /// lets views feed their `@Query` results straight in.
    public static func orderedWorkspaces(_ workspaces: [WorkspaceRecord]) -> [WorkspaceRecord] {
        workspaces.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// Case-insensitive lookup by name.
    public static func find(named name: String, in context: ModelContext) -> WorkspaceRecord? {
        all(in: context).first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
    }

    /// The members of a workspace (`nil` = the ungrouped "Others" section), in display
    /// order. Pure filtering/sorting over an already-fetched list, so views can feed
    /// their `@Query` results straight in.
    public static func members(of workspace: WorkspaceRecord?, in projects: [ProjectRecord]) -> [ProjectRecord] {
        ordered(projects.filter { $0.workspaceID == workspace?.id })
    }

    /// Display order within a section: manual `sortOrder` first, name as the tiebreak
    /// (all-zero sort orders therefore read as plain name order).
    public static func ordered(_ projects: [ProjectRecord]) -> [ProjectRecord] {
        projects.sorted {
            if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    // MARK: Mutations

    /// Creates a workspace (appended after the existing ones). If one with the same
    /// name already exists (case-insensitive), it is returned instead of duplicating.
    @discardableResult
    public static func create(named name: String, in context: ModelContext) -> WorkspaceRecord {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let existing = find(named: trimmed, in: context) { return existing }
        let nextOrder = (all(in: context).map(\.sortOrder).max() ?? -1) + 1
        let workspace = WorkspaceRecord(name: trimmed, sortOrder: nextOrder)
        context.insert(workspace)
        return workspace
    }

    public static func rename(_ workspace: WorkspaceRecord, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        workspace.name = trimmed
    }

    /// Deletes the workspace; its projects are **not** deleted — they move back to the
    /// ungrouped "Others" section.
    public static func delete(_ workspace: WorkspaceRecord, in context: ModelContext) {
        let projects = (try? context.fetch(FetchDescriptor<ProjectRecord>())) ?? []
        for project in projects where project.workspaceID == workspace.id {
            project.workspaceID = nil
        }
        context.delete(workspace)
    }

    /// Moves a project into `workspace` (nil = ungroup back to "Others"). The manual
    /// position resets, so the project slots into the target's name order.
    public static func assign(_ project: ProjectRecord, to workspace: WorkspaceRecord?) {
        project.workspaceID = workspace?.id
        project.sortOrder = 0
    }

    /// Rewrites the manual order of a section's projects by `key` (0, 1, 2, …), which
    /// `ordered(_:)` then respects everywhere the section is shown.
    public static func sortProjects(
        in workspace: WorkspaceRecord?,
        by key: ProjectSortKey,
        context: ModelContext
    ) {
        let projects = (try? context.fetch(FetchDescriptor<ProjectRecord>())) ?? []
        let section = projects.filter { $0.workspaceID == workspace?.id }
        let sorted: [ProjectRecord]
        switch key {
        case .name:
            sorted = section.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .path:
            sorted = section.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
        case .date:
            sorted = section.sorted { $0.dateAdded > $1.dateAdded }
        }
        for (index, project) in sorted.enumerated() {
            project.sortOrder = index
        }
    }
}
