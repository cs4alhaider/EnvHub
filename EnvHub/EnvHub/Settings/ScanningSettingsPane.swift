//
//  ScanningSettingsPane.swift
//  EnvHub
//
//  Filename patterns and excluded directories used by discovery + listing.
//

import SwiftUI
import SwiftData
import Core

struct ScanningSettingsPane: View {
    @Environment(\.modelContext) private var context
    @Query private var rows: [AppSettings]

    var body: some View {
        Form {
            if let settings = rows.first {
                @Bindable var settings = settings
                StringListSection(
                    title: "Filename patterns",
                    footer: "Glob patterns for env files (e.g. .env, .env.*).",
                    placeholder: ".env.*",
                    items: $settings.filenamePatterns
                )
                StringListSection(
                    title: "Excluded directories",
                    footer: "Directory names skipped while scanning.",
                    placeholder: "node_modules",
                    items: $settings.exclusions
                )
            } else {
                ProgressView()
            }
        }
        .formStyle(.grouped)
        .task { _ = EnvHubStore.settings(in: context) }
    }
}
