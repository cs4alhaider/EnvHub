//
//  GeneralSettingsPane.swift
//  EnvHub
//
//  Editor & scanning preferences (masking default, deep-scan default).
//

import SwiftUI
import SwiftData
import Core

struct GeneralSettingsPane: View {
    @Environment(\.modelContext) private var context
    @Query private var rows: [AppSettings]

    var body: some View {
        Form {
            if let settings = rows.first {
                @Bindable var settings = settings
                Section("Editor") {
                    Toggle("Mask values by default", isOn: $settings.maskByDefault)
                    Text("New files open with values hidden; reveal them per-row or with the eye toggle.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Scanning") {
                    Toggle("Deep scan (recurse into subfolders) by default", isOn: $settings.deepScanDefault)
                }
            } else {
                ProgressView()
            }
        }
        .formStyle(.grouped)
        .task { _ = EnvHubStore.settings(in: context) }
    }
}
