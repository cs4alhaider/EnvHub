//
//  AppCommands.swift
//  EnvHub
//
//  Menu-bar commands. The keyboard shortcuts live HERE (not on toolbar buttons), so
//  they keep working no matter what the toolbar shows or whether the sidebar is
//  collapsed. Actions come from the focused window's RootView.
//

import SwiftUI

struct AppCommands: Commands {
    @FocusedValue(\.appActions) private var actions
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // Replace the stock "About EnvHub" panel with our richer window.
        CommandGroup(replacing: .appInfo) {
            Button("About EnvHub") { openWindow(id: "about") }
        }

        CommandGroup(after: .newItem) {
            Button("Add Project…") { actions?.addProject() }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(actions == nil)
            Button("New Workspace…") { actions?.newWorkspace() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(actions == nil)
            Divider()
            Button("Scan for .env Files…") { actions?.scan() }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(actions == nil)
            Button("Import .envenc…") { actions?.importEnvenc() }
                .keyboardShortcut("i", modifiers: .command)
                .disabled(actions == nil)
            Divider()
            // Xcode's "Open Quickly" muscle memory: search everything, jump to a project.
            Button("Search Across Projects…") { actions?.quickOpen() }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(actions == nil)
        }

        CommandGroup(after: .help) {
            Divider()
            Button("Welcome to EnvHub…") { actions?.showWelcome() }
                .disabled(actions == nil)
            Button("EnvHub on GitHub") {
                NSWorkspace.shared.open(URL(string: "https://github.com/cs4alhaider/EnvHub")!)
            }
        }
    }
}
