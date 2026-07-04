//
//  ExportSheet.swift
//  EnvHub
//
//  Password-protected .envenc export of a single file or a whole project.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Core
import Helper

struct ExportSheet: View {
    let projectName: String
    let currentFile: EnvFile?
    let allFiles: [EnvFile]

    @Environment(\.cryptoService) private var crypto
    @Environment(\.dismiss) private var dismiss

    enum Scope: Hashable { case single, project }

    @State private var scope: Scope
    @State private var password = ""
    @State private var confirm = ""
    @State private var error: String?
    @State private var busy = false

    init(projectName: String, currentFile: EnvFile?, allFiles: [EnvFile]) {
        self.projectName = projectName
        self.currentFile = currentFile
        self.allFiles = allFiles
        _scope = State(initialValue: currentFile != nil ? .single : .project)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Export encrypted .envenc", systemImage: "lock.doc").font(.headline)

            if let currentFile {
                Picker("Scope", selection: $scope) {
                    Text("This file — \(currentFile.fileName)").tag(Scope.single)
                    Text("Whole project — \(allFiles.count) file\(allFiles.count == 1 ? "" : "s")").tag(Scope.project)
                }
                .pickerStyle(.radioGroup)
            }

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
                    Text("Encrypting…").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Export…") { export() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid || busy)
            }
        }
        .padding(16)
        .frame(width: 460)
    }

    private var isValid: Bool { !password.isEmpty && password == confirm }

    /// Encrypt off the main actor (`CryptoService` methods are `@concurrent`; scrypt is
    /// deliberately slow), then land back here to present the save panel.
    private func export() {
        busy = true
        error = nil
        let suggested = scope == .single ? (currentFile?.fileName ?? projectName) : projectName

        Task {
            do {
                let data: Data
                switch scope {
                case .single:
                    guard let file = currentFile else { throw ExportUIError.noFile }
                    data = try await crypto.exportSingle(fileURL: file.path, kind: file.kind, password: password)
                case .project:
                    data = try await crypto.exportProject(name: projectName, files: allFiles, password: password)
                }
                busy = false
                presentSavePanel(data, suggestedName: suggested)
            } catch {
                busy = false
                self.error = error.localizedDescription
            }
        }
    }

    private func presentSavePanel(_ data: Data, suggestedName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName + ".envenc"
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

enum ExportUIError: Error { case noFile }
