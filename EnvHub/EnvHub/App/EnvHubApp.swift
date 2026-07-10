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
        // Count launches once per process (drives the occasional star prompt).
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: "launchCount") + 1, forKey: "launchCount")
    }

    var body: some Scene {
        // The id lets "Open in New Tab" spawn additional main windows programmatically
        // (each becomes a tab of the requesting window — see WindowTabbing).
        WindowGroup(id: "main") {
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

        // A project window, keyed by ProjectWindowRef: `.saved` re-uses one window per
        // project (double-click a sidebar row or "Open in New Window"); `.folder` is an
        // ad-hoc window for a folder opened with `envhub .`.
        WindowGroup("Project", id: "project", for: ProjectWindowRef.self) { $ref in
            ProjectWindowView(ref: ref)
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
