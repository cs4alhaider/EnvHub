//
//  SettingsView.swift
//  EnvHub
//
//  The Settings window (⌘,): one tab per pane (each pane lives in its own file).
//

import SwiftUI

struct SettingsView: View {
    enum Tab: String {
        case general, classification, scanning, search, data, about
    }

    /// Initial tab — overridable via ENVHUB_SETTINGS_TAB (screenshot/test hook).
    @State private var selection: Tab = ProcessInfo.processInfo
        .environment["ENVHUB_SETTINGS_TAB"].flatMap(Tab.init(rawValue:)) ?? .general

    var body: some View {
        TabView(selection: $selection) {
            GeneralSettingsPane()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(Tab.general)
            ClassificationSettingsPane()
                .tabItem { Label("Classification", systemImage: "tag") }
                .tag(Tab.classification)
            ScanningSettingsPane()
                .tabItem { Label("Scanning", systemImage: "magnifyingglass") }
                .tag(Tab.scanning)
            SearchSettingsPane()
                .tabItem { Label("Search", systemImage: "text.magnifyingglass") }
                .tag(Tab.search)
            DataSettingsPane()
                .tabItem { Label("Data", systemImage: "externaldrive") }
                .tag(Tab.data)
            AboutSettingsPane()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(Tab.about)
        }
        .frame(width: 580, height: 500)
    }
}
