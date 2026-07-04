//
//  SettingsView.swift
//  EnvHub
//
//  The Settings window: one tab per pane (each pane lives in its own file).
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsPane()
                .tabItem { Label("General", systemImage: "gearshape") }
            ClassificationSettingsPane()
                .tabItem { Label("Classification", systemImage: "tag") }
            ScanningSettingsPane()
                .tabItem { Label("Scanning", systemImage: "magnifyingglass") }
        }
        .frame(width: 580, height: 480)
    }
}
