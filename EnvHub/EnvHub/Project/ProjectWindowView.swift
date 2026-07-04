//
//  ProjectWindowView.swift
//  EnvHub
//
//  A project opened in its own window (double-click a sidebar row, or
//  "Open in New Window" in the context menu). The window is keyed by project ID,
//  so opening the same project again focuses the existing window.
//

import SwiftUI
import SwiftData
import Core

struct ProjectWindowView: View {
    let projectID: UUID?
    @Query private var projects: [ProjectRecord]
    @Query private var settingsRows: [AppSettings]

    var body: some View {
        if let projectID, let project = projects.first(where: { $0.id == projectID }) {
            ProjectDetailView(project: project)
                .frame(minWidth: 620, minHeight: 420)
                // This is a separate window scene, so it needs the catalog injected too.
                .environment(\.environmentCatalog, settingsRows.first?.environmentCatalog ?? .builtin)
        } else {
            // The project was removed while this window was open (or the window was
            // restored after a removal).
            ContentUnavailableView(
                "Project Removed",
                systemImage: "folder.badge.questionmark",
                description: Text("This project is no longer in EnvHub.")
            )
            .frame(minWidth: 420, minHeight: 300)
            .navigationTitle("EnvHub")
        }
    }
}
