//
//  EnvHubApp.swift
//  EnvHub
//

import SwiftUI
import SwiftData
import Core
import Helper

@main
struct EnvHubApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try EnvHubStore.container()
        } catch {
            fatalError("Failed to create the EnvHub data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // Inject Core's stateless services once, at the root, via the custom
                // EnvironmentKeys defined in the Helper module.
                .environment(\.scanService, ScanService())
                .environment(\.cryptoService, CryptoService())
        }
        .modelContainer(container)
        .defaultSize(width: 1180, height: 760)
        // Keyboard shortcuts live in the menu bar (not on toolbar buttons), so they
        // work regardless of the sidebar/toolbar state.
        .commands { AppCommands() }

        // One window per project, keyed by ID (double-click a sidebar row or use
        // "Open in New Window"). Re-opening the same project focuses its window.
        WindowGroup("Project", id: "project", for: UUID.self) { $projectID in
            ProjectWindowView(projectID: projectID)
                .environment(\.scanService, ScanService())
                .environment(\.cryptoService, CryptoService())
        }
        .modelContainer(container)
        .defaultSize(width: 960, height: 680)

        // Custom "About EnvHub" window (App menu → About), richer than the stock panel.
        Window("About EnvHub", id: "about") {
            AboutWindowView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        Settings {
            SettingsView()
        }
        .modelContainer(container)
    }
}
