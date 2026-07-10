//
//  ProjectWindowView.swift
//  EnvHub
//
//  A project opened in its own window. The window is keyed by `ProjectWindowRef`:
//  `.saved` re-uses one window per project (double-click a sidebar row or
//  "Open in New Window"); `.folder` is an ad-hoc window for a folder opened with
//  `envhub .` that was never added to the sidebar.
//

import SwiftUI
import SwiftData
import Core

struct ProjectWindowView: View {
    let ref: ProjectWindowRef?
    @Query private var projects: [ProjectRecord]
    @Query private var settingsRows: [AppSettings]

    var body: some View {
        content
            // This is a separate window scene, so it needs the catalog injected too.
            .environment(\.environmentCatalog, settingsRows.first?.environmentCatalog ?? .builtin)
            // Group standalone project windows for Merge All Windows.
            .background(WindowAccessor { WindowTabbing.markProjectWindow($0) })
    }

    @ViewBuilder
    private var content: some View {
        switch ref {
        case .saved(let id):
            if let project = projects.first(where: { $0.id == id }) {
                ProjectDetailView(project: ProjectRef(project))
                    .frame(minWidth: 620, minHeight: 420)
            } else {
                removed
            }
        case .folder(let path):
            // Ad-hoc folder — not a saved project, shown from the path alone.
            ProjectDetailView(project: ProjectRef(folder: URL(filePath: path)))
                .frame(minWidth: 620, minHeight: 420)
        case nil:
            empty
        }
    }

    /// The project was removed while its window was open (or restored after removal).
    private var removed: some View {
        ContentUnavailableView(
            "Project Removed",
            systemImage: "folder.badge.questionmark",
            description: Text("This project is no longer in EnvHub.")
        )
        .frame(minWidth: 420, minHeight: 300)
        .navigationTitle("EnvHub")
    }

    /// A window/tab opened with no project — e.g. the tab bar's "+" button.
    private var empty: some View {
        ContentUnavailableView(
            "No Project Open",
            systemImage: "folder",
            description: Text("Double-click a project in the EnvHub window, or right-click it and choose “Open in New Tab”.")
        )
        .frame(minWidth: 420, minHeight: 300)
        .navigationTitle("EnvHub")
    }
}
