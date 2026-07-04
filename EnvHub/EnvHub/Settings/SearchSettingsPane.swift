//
//  SearchSettingsPane.swift
//  EnvHub
//
//  Which environments' variables appear in search results (sidebar search and
//  Quick Open ⇧⌘O). Exclusion-based, so a newly-added environment is searchable
//  until you turn it off. Environments themselves are defined in the Classification
//  tab.
//

import SwiftUI
import SwiftData
import Core

struct SearchSettingsPane: View {
    @Environment(\.modelContext) private var context
    @Query private var rows: [AppSettings]

    var body: some View {
        Form {
            if let settings = rows.first {
                Section {
                    ForEach(settings.environmentCatalog.definitions) { definition in
                        Toggle(isOn: binding(settings, definition.kind)) {
                            HStack(spacing: 8) {
                                Circle().fill(definition.color.color).frame(width: 8, height: 8)
                                Text(definition.title)
                            }
                        }
                    }
                } header: {
                    Text("Environments in search results")
                } footer: {
                    Text("Applies to the sidebar search and Quick Open (⇧⌘O). Environment tabs and the editor always show every file. Add or rename environments in the Classification tab.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section {
                    Text(settings.filenamePatterns.joined(separator: "   "))
                        .monospaced()
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Recognized filenames")
                } footer: {
                    Text("Files matching these patterns are indexed and searchable — edit them in the Scanning tab.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                ProgressView()
            }
        }
        .formStyle(.grouped)
        .task { _ = EnvHubStore.settings(in: context) }
    }

    private func binding(_ settings: AppSettings, _ kind: EnvKind) -> Binding<Bool> {
        Binding(
            get: { settings.isSearchable(kind) },
            set: { settings.setSearchable(kind, $0) }
        )
    }
}
