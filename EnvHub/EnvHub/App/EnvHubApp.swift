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

        Settings {
            SettingsView()
        }
        .modelContainer(container)
    }
}
