//
//  NewEnvFileSheet.swift
//  EnvHub
//
//  Create a new env file of any type (.env, .env.production, .env.example, custom),
//  optionally seeded from an existing file's keys, with a .gitignore choice.
//

import SwiftUI
import Core

struct NewEnvFileSheet: View {
    let projectFolder: URL
    let existingFiles: [EnvFile]
    let onCreated: (URL) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ".env"
    @State private var copyFrom: URL?
    @State private var addToGitignore = true
    @State private var isRepo = false
    @State private var error: String?

    private let presets = [
        ".env", ".env.local", ".env.development", ".env.staging",
        ".env.production", ".env.test", ".env.example",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("New env file", systemImage: "doc.badge.plus").font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(presets, id: \.self) { preset in
                    Button { setPreset(preset) } label: {
                        Text(preset).font(.caption).monospaced().frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(name == preset ? .accentColor : nil)
                }
            }

            LabeledContent("Filename") {
                TextField(".env", text: $name).textFieldStyle(.roundedBorder).monospaced()
            }

            if !existingFiles.isEmpty {
                Picker("Copy keys from", selection: $copyFrom) {
                    Text("Blank").tag(URL?.none)
                    ForEach(existingFiles) { file in
                        Text(file.fileName).tag(Optional(file.path))
                    }
                }
                Text("Copies keys with empty values — great for making a committed .env.example.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if isRepo {
                Toggle("Add to .gitignore", isOn: $addToGitignore)
                Text(".env.example is meant to be committed — leave this off for example files.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValidName)
            }
        }
        .padding(16)
        .frame(width: 470)
        .task { isRepo = GitService.repoRoot(for: projectFolder) != nil }
        .onChange(of: name) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespaces) == ".env.example" { addToGitignore = false }
        }
    }

    private var isValidName: Bool {
        let n = name.trimmingCharacters(in: .whitespaces)
        return n == ".env" || n.hasPrefix(".env.")
    }

    private func setPreset(_ preset: String) {
        name = preset
        addToGitignore = preset != ".env.example"
    }

    private func create() {
        let filename = name.trimmingCharacters(in: .whitespaces)
        let url = projectFolder.appendingPathComponent(filename)
        do {
            try EnvFileService.create(at: url, copyingKeysFrom: copyFrom)
            if isRepo && addToGitignore {
                try? GitService.addToGitignore(filename, folder: projectFolder)
            }
            onCreated(url)
            dismiss()
        } catch let e as EnvExportError {
            if case .fileExists = e { error = "“\(filename)” already exists." }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
