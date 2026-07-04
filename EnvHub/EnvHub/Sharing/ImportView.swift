//
//  ImportView.swift
//  EnvHub
//
//  Decrypts a .envenc file (prompting for the password) and materializes its files
//  into a chosen folder.
//

import SwiftUI
import AppKit
import Core
import Helper

struct ImportView: View {
    let fileURL: URL

    @Environment(\.cryptoService) private var crypto
    @Environment(\.dismiss) private var dismiss

    @State private var password = ""
    @State private var export: EnvExport?
    @State private var destination: URL?
    @State private var overwrite = false
    @State private var busy = false
    @State private var error: String?
    @State private var written: [URL]?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Import \(fileURL.lastPathComponent)", systemImage: "lock.open.doc").font(.headline)

            if let written {
                Label("Imported \(written.count) file\(written.count == 1 ? "" : "s").", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent) }
            } else if let export {
                contents(export)
            } else {
                passwordPhase
            }

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(width: 480)
    }

    private var passwordPhase: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Enter the password used to encrypt this file.")
                .font(.caption).foregroundStyle(.secondary)
            SecureField("Password", text: $password)
            HStack {
                if busy { ProgressView().controlSize(.small); Text("Decrypting…").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Decrypt") { decrypt() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(password.isEmpty || busy)
            }
        }
    }

    private func contents(_ export: EnvExport) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(typeLabel(export.type)): \(export.name)")
                .font(.subheadline)
            // Library exports can hold hundreds of files — show a preview, not all.
            ForEach(Array(export.files.prefix(8).enumerated()), id: \.offset) { _, file in
                Label(
                    "\(file.project.map { $0 + "/" } ?? "")\(file.name) · \(file.variables.count) variable\(file.variables.count == 1 ? "" : "s")",
                    systemImage: "doc.text"
                )
                .monospaced().font(.caption)
            }
            if export.files.count > 8 {
                Text("…and \(export.files.count - 8) more file\(export.files.count - 8 == 1 ? "" : "s")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Text(destination?.path(percentEncoded: false) ?? "Choose a destination folder…")
                    .lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(destination == nil ? .secondary : .primary)
                Spacer()
                Button("Choose Folder…") { chooseDestination() }
            }
            Toggle("Overwrite existing files", isOn: $overwrite)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Import") { materialize(export) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(destination == nil)
            }
        }
    }

    private func typeLabel(_ type: EnvExport.Kind) -> String {
        switch type {
        case .single: "File"
        case .project: "Project"
        case .library: "Library"
        }
    }

    // MARK: Actions

    /// Read + decrypt off the main actor. `EnvelopeError` is `LocalizedError` in the
    /// package, so `localizedDescription` is already user-friendly here.
    private func decrypt() {
        busy = true
        error = nil
        Task {
            do {
                export = try await crypto.decrypt(contentsOf: fileURL, password: password)
                busy = false
            } catch {
                busy = false
                self.error = error.localizedDescription
            }
        }
    }

    private func materialize(_ export: EnvExport) {
        guard let destination else { return }
        error = nil
        Task {
            do {
                written = try await crypto.materialize(export, into: destination, overwrite: overwrite)
            } catch let e as EnvExportError {
                // Add the app-specific remedy on top of the shared message.
                error = (e.errorDescription ?? "A file already exists.") + " Turn on “Overwrite” to replace it."
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Choose"
        panel.message = "Choose where to write the imported .env file(s)"
        if panel.runModal() == .OK { destination = panel.url }
    }
}
