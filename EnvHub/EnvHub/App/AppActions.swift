//
//  AppActions.swift
//  EnvHub
//
//  The app-wide actions (add project, scan, import, …) owned by RootView and exposed
//  two ways: through the SwiftUI environment for descendant views (sidebar empty
//  state, onboarding), and through focused values for the menu-bar commands. Keeping
//  them on RootView — not on the sidebar's toolbar — is what makes them survive the
//  sidebar collapsing (toolbar items attached to a collapsed column can vanish, and
//  their keyboard shortcuts died with them).
//

import SwiftUI

struct AppActions {
    var addProject: () -> Void
    var newWorkspace: () -> Void
    var scan: () -> Void
    var importEnvenc: () -> Void
    var showWelcome: () -> Void
    /// The ⇧⌘O cross-project search popup.
    var quickOpen: () -> Void
}

extension EnvironmentValues {
    /// Injected by RootView; `nil` only in previews that don't set it.
    @Entry var appActions: AppActions?
}

extension FocusedValues {
    /// Published by RootView via `.focusedSceneValue` so `AppCommands` can reach the
    /// active window's actions.
    @Entry var appActions: AppActions?
}
