import ArgumentParser
import Foundation
import SwiftData
import Core

/// `envhub workspace …` — manage the same workspaces the app shows in its sidebar.
/// The CLI opens the app's shared store (`EnvHubStore.storeURL`), so changes made
/// here appear in the app and vice versa.
struct Workspace: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List and organize the app's project workspaces.",
        subcommands: [List.self, Create.self, Rename.self, Delete.self, Move.self, Sort.self],
        defaultSubcommand: List.self
    )

    // MARK: Shared helpers

    /// The shared app/CLI store, on a context the CLI owns (not SwiftData's
    /// main-actor `mainContext`). It does not autosave — mutating commands must
    /// `context.save()` before the process exits.
    static func openContext() throws -> ModelContext {
        ModelContext(try EnvHubStore.container())
    }

    /// Resolve a workspace argument; the keywords `none`/`others` mean "no workspace".
    static func resolveWorkspace(_ name: String, in context: ModelContext) throws -> WorkspaceRecord? {
        if ["none", "others"].contains(name.lowercased()) { return nil }
        guard let workspace = WorkspaceStore.find(named: name, in: context) else {
            throw CLIError.workspaceNotFound(name)
        }
        return workspace
    }

    /// Resolve a project by folder path (canonical) or, failing that, by unique name.
    static func resolveProject(_ identifier: String, in context: ModelContext) throws -> ProjectRecord {
        let projects = (try? context.fetch(FetchDescriptor<ProjectRecord>())) ?? []
        let canonical = ProjectStore.canonicalPath(for: URL(fileURLWithPath: identifier))
        if let byPath = projects.first(where: { ProjectStore.canonicalPath(for: $0.url) == canonical }) {
            return byPath
        }
        let byName = projects.filter { $0.name.localizedCaseInsensitiveCompare(identifier) == .orderedSame }
        guard byName.count == 1 else { throw CLIError.projectNotFound(identifier) }
        return byName[0]
    }

    static func printSection(_ title: String, _ members: [ProjectRecord]) {
        print("\(title) (\(members.count) project\(members.count == 1 ? "" : "s"))")
        for project in members {
            print("  \(project.isPinned ? "📌" : "•") \(project.name) — \(project.path)")
        }
    }

    // MARK: Subcommands

    struct List: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "List workspaces and their projects.")

        func run() async throws {
            let context = try Workspace.openContext()
            let projects = (try? context.fetch(FetchDescriptor<ProjectRecord>())) ?? []
            let workspaces = WorkspaceStore.all(in: context)

            guard !projects.isEmpty || !workspaces.isEmpty else {
                print("No projects or workspaces yet — add projects in the app, or create a workspace with `envhub workspace create <name>`.")
                return
            }
            for workspace in workspaces {
                Workspace.printSection(workspace.name, WorkspaceStore.members(of: workspace, in: projects))
            }
            let others = WorkspaceStore.members(of: nil, in: projects)
            if !others.isEmpty {
                Workspace.printSection(workspaces.isEmpty ? "Projects" : "Others", others)
            }
        }
    }

    struct Create: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Create a workspace.")

        @Argument(help: "The workspace name.")
        var name: String

        func run() async throws {
            let context = try Workspace.openContext()
            let workspace = WorkspaceStore.create(named: name, in: context)
            try context.save()
            print("Workspace “\(workspace.name)” ready.")
        }
    }

    struct Rename: AsyncParsableCommand {
        static let configuration = CommandConfiguration(abstract: "Rename a workspace.")

        @Argument(help: "The current workspace name.")
        var name: String

        @Argument(help: "The new name.")
        var newName: String

        func run() async throws {
            let context = try Workspace.openContext()
            guard let workspace = try Workspace.resolveWorkspace(name, in: context) else {
                throw CLIError.workspaceNotFound(name)
            }
            WorkspaceStore.rename(workspace, to: newName)
            try context.save()
            print("Renamed “\(name)” → “\(workspace.name)”.")
        }
    }

    struct Delete: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Delete a workspace (its projects move back to Others; nothing on disk is touched).")

        @Argument(help: "The workspace name.")
        var name: String

        func run() async throws {
            let context = try Workspace.openContext()
            guard let workspace = try Workspace.resolveWorkspace(name, in: context) else {
                throw CLIError.workspaceNotFound(name)
            }
            WorkspaceStore.delete(workspace, in: context)
            try context.save()
            print("Deleted “\(name)”; its projects are back in Others.")
        }
    }

    struct Move: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Move a project into a workspace (use “none” to ungroup).")

        @Argument(help: "The project's folder path, or its (unique) display name.")
        var project: String

        @Argument(help: "The target workspace name, or “none”.")
        var workspace: String

        func run() async throws {
            let context = try Workspace.openContext()
            let record = try Workspace.resolveProject(project, in: context)
            let target = try Workspace.resolveWorkspace(workspace, in: context)
            WorkspaceStore.assign(record, to: target)
            try context.save()
            print("Moved “\(record.name)” to \(target.map { "“\($0.name)”" } ?? "Others").")
        }
    }

    struct Sort: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Sort a workspace's projects (use “none” for the ungrouped section).")

        @Argument(help: "The workspace name, or “none”.")
        var workspace: String

        @Option(name: .customLong("by"), help: "Sort key: name, path, or date (newest first).")
        var by: ProjectSortKey = .name

        func run() async throws {
            let context = try Workspace.openContext()
            let target = try Workspace.resolveWorkspace(workspace, in: context)
            WorkspaceStore.sortProjects(in: target, by: by, context: context)
            try context.save()
            let projects = (try? context.fetch(FetchDescriptor<ProjectRecord>())) ?? []
            Workspace.printSection(
                target?.name ?? "Others",
                WorkspaceStore.members(of: target, in: projects)
            )
        }
    }
}

extension ProjectSortKey: ExpressibleByArgument {}
