//
//  RootView.swift
//  EnvHub
//
//  The top-level sidebar + detail split view, plus cross-project search.
//

import SwiftUI
import SwiftData
import Core

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var projects: [ProjectRecord]
    @Query private var settingsRows: [AppSettings]
    /// Sidebar selection — a set so projects can be multi-selected for bulk
    /// move/remove; the detail pane shows an editor only for a single selection.
    @State private var selection: Set<UUID> = []
    @State private var searchText = ""
    @State private var index = SearchIndex.empty

    var body: some View {
        // One search pass per render, shared by the sidebar filter and the results list.
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let hits = ProjectSearch.search(query, in: index)

        NavigationSplitView {
            SidebarView(
                selection: $selection,
                matchingIDs: matchingIDs(query: query, hits: hits),
                fileCounts: index.fileCounts
            )
            .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            detail(query: query, hits: hits)
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search projects & keys")
        .task {
            _ = EnvHubStore.settings(in: context)
            // Testing/demo hook: auto-add a project folder when launched with
            // ENVHUB_ADD_PROJECT=<path> (used for headless UI smoke tests).
            if let path = ProcessInfo.processInfo.environment["ENVHUB_ADD_PROJECT"], !path.isEmpty,
               let added = ProjectStore.addProject(at: URL(filePath: path), to: context) {
                selection = [added.id]
            }
        }
        .task(id: indexKey) { await rebuildIndex() }
    }

    @ViewBuilder
    private func detail(query: String, hits: [IndexedVariable]) -> some View {
        if !query.isEmpty {
            SearchResultsView(query: query, hits: hits) { projectID, _ in
                selection = [projectID]
                searchText = ""
            }
        } else if selection.count == 1, let id = selection.first,
                  let project = projects.first(where: { $0.id == id }) {
            ProjectDetailView(project: project)
        } else if selection.count > 1 {
            ContentUnavailableView {
                Label("\(selection.count) Projects Selected", systemImage: "square.stack.3d.up")
            } description: {
                Text("Right-click the selection in the sidebar to move the projects to a workspace or remove them.")
            }
        } else {
            ContentUnavailableView(
                "No Project Selected",
                systemImage: "sidebar.left",
                description: Text("Select a project, add a folder, or scan for .env files.")
            )
        }
    }

    // MARK: Search

    /// Project IDs that match the query (via variable hits or name/path). `nil` when not
    /// searching, meaning "show everything".
    private func matchingIDs(query: String, hits: [IndexedVariable]) -> Set<UUID>? {
        guard !query.isEmpty else { return nil }
        var ids = Set(hits.map(\.projectID))
        for project in projects where ProjectSearch.projectMatches(query: query, name: project.name, path: project.path) {
            ids.insert(project.id)
        }
        return ids
    }

    // MARK: Index

    /// Everything the index depends on: rebuild when projects are added/removed or the
    /// user edits filename patterns / classification rules in Settings.
    private struct IndexKey: Hashable {
        var projectIDs: [UUID]
        var patterns: [String]
        var rules: [ClassificationRule]
    }

    private var indexKey: IndexKey {
        IndexKey(
            projectIDs: projects.map(\.id),
            patterns: settingsRows.first?.filenamePatterns ?? ScanConfig.defaultFilenamePatterns,
            rules: settingsRows.first?.classificationRules ?? ClassificationRule.defaults
        )
    }

    /// Rebuilds the in-memory search index (reads each project's env files once,
    /// off the main actor — see `SearchIndex.build`).
    private func rebuildIndex() async {
        let sources = projects.map { Project(id: $0.id, name: $0.name, path: $0.url) }
        let settings = EnvHubStore.settings(in: context)
        index = await SearchIndex.build(
            projects: sources,
            rules: settings.classificationRules,
            patterns: settings.filenamePatterns
        )
    }
}
