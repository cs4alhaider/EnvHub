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
    @State private var selection: UUID?
    @State private var searchText = ""
    @State private var index: [IndexedVariable] = []

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selection, matchingIDs: matchingIDs)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280)
        } detail: {
            detail
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search projects & keys")
        .task {
            _ = EnvHubStore.settings(in: context)
            // Testing/demo hook: auto-add a project folder when launched with
            // ENVHUB_ADD_PROJECT=<path> (used for headless UI smoke tests).
            if let path = ProcessInfo.processInfo.environment["ENVHUB_ADD_PROJECT"], !path.isEmpty,
               let added = ProjectStore.addProject(at: URL(filePath: path), to: context) {
                selection = added.id
            }
        }
        .task(id: projects.map(\.id)) { await rebuildIndex() }
    }

    @ViewBuilder
    private var detail: some View {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            SearchResultsView(query: query, hits: hits) { projectID, _ in
                selection = projectID
                searchText = ""
            }
        } else if let id = selection, let project = projects.first(where: { $0.id == id }) {
            ProjectDetailView(project: project)
        } else {
            ContentUnavailableView(
                "No Project Selected",
                systemImage: "sidebar.left",
                description: Text("Select a project, add a folder, or scan for .env files.")
            )
        }
    }

    // MARK: Search

    private var hits: [IndexedVariable] { ProjectSearch.search(searchText, in: index) }

    /// Project IDs that match the query (via variable hits or name/path). `nil` when not
    /// searching, meaning "show everything".
    private var matchingIDs: Set<UUID>? {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return nil }
        var ids = Set(hits.map(\.projectID))
        for project in projects where project.name.lowercased().contains(q) || project.path.lowercased().contains(q) {
            ids.insert(project.id)
        }
        return ids
    }

    /// Build the in-memory search index off the main actor (reads each project's env
    /// files once). Rebuilds when the set of projects changes.
    private func rebuildIndex() async {
        let refs = projects.map { (id: $0.id, name: $0.name, path: $0.path, url: $0.url) }
        index = await Task.detached(priority: .utility) { () -> [IndexedVariable] in
            var result: [IndexedVariable] = []
            for ref in refs {
                for file in ProjectLoader.envFiles(in: ref.url, rules: ClassificationRule.defaults) {
                    guard let doc = try? EnvFileService.load(file.path) else { continue }
                    for variable in doc.variables {
                        result.append(IndexedVariable(
                            projectID: ref.id, projectName: ref.name, projectPath: ref.path,
                            fileURL: file.path, fileName: file.fileName, kind: file.kind,
                            key: variable.key, value: variable.value
                        ))
                    }
                }
            }
            return result
        }.value
    }
}
