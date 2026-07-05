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
            removed
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
}
