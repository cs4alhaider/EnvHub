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
            Text("\(export.type == .project ? "Project" : "File"): \(export.name)")
                .font(.subheadline)
            ForEach(export.files, id: \.name) { file in
                Label("\(file.name) · \(file.variables.count) variable\(file.variables.count == 1 ? "" : "s")", systemImage: "doc.text")
                    .monospaced().font(.caption)
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

    // MARK: Actions

    private func decrypt() {
        busy = true
        error = nil
        let crypto = self.crypto
        let url = fileURL
        let password = self.password
        Task {
            do {
                let data = try Data(contentsOf: url)
                let result = try await Task.detached(priority: .userInitiated) {
                    try crypto.decrypt(data, password: password)
                }.value
                await MainActor.run { busy = false; export = result }
            } catch {
                await MainActor.run { busy = false; self.error = friendly(error) }
            }
        }
    }

    private func materialize(_ export: EnvExport) {
        guard let destination else { return }
        error = nil
        do {
            written = try crypto.materialize(export, into: destination, overwrite: overwrite)
        } catch let e as EnvExportError {
            if case .fileExists(let url) = e {
                error = "“\(url.lastPathComponent)” already exists. Turn on “Overwrite” to replace it."
            }
        } catch {
            self.error = error.localizedDescription
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

    private func friendly(_ error: Error) -> String {
        guard let e = error as? EnvelopeError else { return error.localizedDescription }
        switch e {
        case .wrongPasswordOrCorrupted: return "Wrong password, or the file has been tampered with."
        case .unsupportedVersion(let v): return "Unsupported .envenc version (\(v))."
        case .unsupportedKDF(let k): return "Unsupported key-derivation function (\(k))."
        case .malformedEnvelope: return "This isn’t a valid .envenc file."
        case .invalidScryptParams: return "The file has invalid encryption parameters."
        }
    }
}
