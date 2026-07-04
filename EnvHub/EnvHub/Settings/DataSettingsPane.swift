//
//  DataSettingsPane.swift
//  EnvHub
//
//  Library-wide data management: export everything as one encrypted .envenc,
//  forget all projects, or reset EnvHub entirely. Nothing here ever deletes
//  .env files on disk.
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers
import Core
import Helper

struct DataSettingsPane: View {
    @Environment(\.modelContext) private var context
    @Query private var projects: [ProjectRecord]
    @Query private var workspaces: [WorkspaceRecord]

    @State private var showExportAll = false
    @State private var confirmRemoveAll = false
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section("Library") {
                LabeledContent("Projects", value: "\(projects.count)")
                LabeledContent("Workspaces", value: "\(workspaces.count)")
                LabeledContent("Data store") {
                    HStack(spacing: 8) {
                        Text(EnvHubStore.storeURL.path(percentEncoded: false))
                            .font(.caption).monospaced()
                            .lineLimit(1).truncationMode(.middle)
                        Button("Reveal") { FinderActions.reveal(EnvHubStore.storeURL) }
                            .controlSize(.small)
                    }
                }
            }

            Section {
                Button("Export All Variables…") { showExportAll = true }
                    .disabled(projects.isEmpty)
            } header: {
                Text("Export")
            } footer: {
                Text("Every project's env files in one password-encrypted .envenc. Importing it recreates one folder per project.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section {
                Button("Remove All Projects…", role: .destructive) { confirmRemoveAll = true }
                    .disabled(projects.isEmpty)
                Button("Reset EnvHub…", role: .destructive) { confirmReset = true }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("Both only clear what EnvHub remembers — no .env files on disk are ever touched.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { _ = EnvHubStore.settings(in: context) }
        .sheet(isPresented: $showExportAll) { ExportAllSheet() }
        .confirmationDialog(
            "Remove all \(projects.count) projects?",
            isPresented: $confirmRemoveAll,
            titleVisibility: .visible
        ) {
            Button("Remove All Projects", role: .destructive) {
                ProjectStore.removeAll(in: context)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("EnvHub forgets them; workspaces and settings stay. Files on disk are untouched.")
        }
        .confirmationDialog(
            "Reset EnvHub?",
            isPresented: $confirmReset,
            titleVisibility: .visible
        ) {
            Button("Reset Everything", role: .destructive) {
                EnvHubStore.reset(in: context)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Removes all projects, workspaces, scan folders, and preferences. Files on disk are untouched; the welcome flow returns on next launch.")
        }
    }
}

/// Password prompt + save panel for the whole-library export.
private struct ExportAllSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.cryptoService) private var crypto
    @Environment(\.dismiss) private var dismiss
    @Query private var projects: [ProjectRecord]

    @State private var password = ""
    @State private var confirm = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Export all variables", systemImage: "lock.doc").font(.headline)
            Text("\(projects.count) project\(projects.count == 1 ? "" : "s") into one encrypted .envenc.")
                .font(.caption).foregroundStyle(.secondary)

            SecureField("Password", text: $password)
            SecureField("Confirm password", text: $confirm)
            if !confirm.isEmpty && password != confirm {
                Text("Passwords don’t match.").font(.caption).foregroundStyle(.red)
            }
            Text("AES-256-GCM, scrypt key derivation. Keep this password safe — there’s no recovery.")
                .font(.caption).foregroundStyle(.secondary)
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                if busy {
                    ProgressView().controlSize(.small)
                    Text("Encrypting \(projects.count) projects…").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Export…") { export() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(password.isEmpty || password != confirm || busy)
            }
        }
        .padding(16)
        .frame(width: 460)
    }

    private func export() {
        busy = true
        error = nil
        let settings = EnvHubStore.settings(in: context)
        let sources = projects.map { Project(id: $0.id, name: $0.name, path: $0.url) }

        Task {
            do {
                let data = try await crypto.exportLibrary(
                    name: "EnvHub Library",
                    projects: sources,
                    rules: settings.classificationRules,
                    patterns: settings.filenamePatterns,
                    password: password
                )
                busy = false
                presentSavePanel(data)
            } catch {
                busy = false
                self.error = error.localizedDescription
            }
        }
    }

    private func presentSavePanel(_ data: Data) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "EnvHub-All.envenc"
        if let type = UTType(filenameExtension: "envenc") {
            panel.allowedContentTypes = [type]
        }
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
