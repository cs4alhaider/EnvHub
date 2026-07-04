//
//  EnvFileEditor.swift
//  EnvHub
//
//  Structured key/value editor with masking + inline validation, plus a raw
//  "developer" text view. Backup-then-write Save.
//

import SwiftUI
import AppKit
import Core

struct EnvFileEditor: View {
    @Bindable var model: EnvFileEditorModel
    @State private var selection: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            controlBar
            Divider()
            if let error = model.loadError {
                notice(error, systemImage: "xmark.octagon.fill", tint: .red)
            }
            if model.documentIssueCount > 0 && model.mode == .table {
                notice(
                    "\(model.documentIssueCount) line\(model.documentIssueCount == 1 ? "" : "s") couldn’t be parsed as KEY=VALUE — preserved on disk but not shown here.",
                    systemImage: "exclamationmark.triangle.fill", tint: .orange
                )
            }
            if model.mode == .raw {
                rawEditor
            } else {
                table
            }
            if let error = model.saveError {
                notice("Save failed: \(error)", systemImage: "xmark.octagon.fill", tint: .red)
            }
        }
    }

    // MARK: Control bar

    private var controlBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text").foregroundStyle(.secondary)
            Text(model.fileURL.lastPathComponent).monospaced().fontWeight(.medium)
            Text("· \(model.variableCount) var\(model.variableCount == 1 ? "" : "s")")
                .font(.caption).foregroundStyle(.secondary)
            if model.isDirty {
                Circle().fill(.orange).frame(width: 7, height: 7).help("Unsaved changes")
            }

            // Mode toggle + Copy are anchored on the LEFT (before the Spacer) so they
            // never shift when the trailing table-only buttons (eye / + / −) appear or
            // disappear.
            Picker("", selection: Binding(get: { model.mode }, set: { model.setMode($0) })) {
                Text("Table").tag(EnvFileEditorModel.EditorMode.table)
                Text("Raw").tag(EnvFileEditorModel.EditorMode.raw)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .help("Switch between the structured table and raw text")

            Button {
                copyAll()
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy all as text")

            Spacer()

            if model.mode == .table {
                Button {
                    model.revealAll.toggle()
                } label: {
                    Image(systemName: model.revealAll ? "eye.slash" : "eye")
                }
                .help(model.revealAll ? "Hide all values" : "Reveal all values")

                Button { selection = [model.addRow()] } label: { Image(systemName: "plus") }
                    .help("Add variable")

                Button(role: .destructive) {
                    model.deleteRows(selection)
                    selection = []
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(selection.isEmpty)
                .help("Delete selected")
            }

            Button("Revert") { model.revert() }
                .disabled(!model.isDirty)

            Button("Save") { model.save() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!model.isDirty)
                .buttonStyle(.borderedProminent)
        }
        .padding(8)
    }

    // MARK: Raw developer view

    private var rawEditor: some View {
        TextEditor(text: $model.rawText)
            .font(.system(.body, design: .monospaced))
            .textEditorStyle(.plain)
            .padding(8)
            .background(.background)
    }

    // MARK: Table

    @ViewBuilder
    private var table: some View {
        if model.rows.isEmpty && model.loadError == nil {
            // Clean empty state — no blank striped rows behind it.
            ContentUnavailableView {
                Label("No Variables", systemImage: "list.bullet.rectangle")
            } description: {
                Text("This file has no variables yet.")
            } actions: {
                Button("Add Variable") { selection = [model.addRow()] }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Table(model.rows, selection: $selection) {
                TableColumn("Key") { row in
                    TextField("KEY", text: keyBinding(row))
                        .textFieldStyle(.plain)
                        .monospaced()
                }
                .width(min: 140, ideal: 220)

                TableColumn("Value") { row in
                    valueCell(row)
                }
                .width(min: 200, ideal: 380)

                TableColumn("") { row in
                    statusCell(row)
                }
                .width(24)
            }
            .tableStyle(.inset)
        }
    }

    @ViewBuilder
    private func valueCell(_ row: EnvVar) -> some View {
        HStack(spacing: 6) {
            if model.isRevealed(row.id) {
                TextField("value", text: valueBinding(row))
                    .textFieldStyle(.plain)
                    .monospaced()
            } else {
                Text(masked(row.value))
                    .foregroundStyle(.secondary)
                    .monospaced()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { model.toggleReveal(row.id) }
            }
            Button {
                model.toggleReveal(row.id)
            } label: {
                Image(systemName: model.isRevealed(row.id) ? "eye.slash" : "eye")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help(model.isRevealed(row.id) ? "Hide value" : "Reveal value")
        }
    }

    @ViewBuilder
    private func statusCell(_ row: EnvVar) -> some View {
        switch model.status(for: row) {
        case .ok:
            EmptyView()
        case .warning(let message):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .help(message)
        }
    }

    // MARK: Helpers

    private func copyAll() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(model.currentText, forType: .string)
    }

    private func masked(_ value: String) -> String {
        value.isEmpty ? "" : String(repeating: "•", count: min(max(value.count, 3), 20))
    }

    private func keyBinding(_ row: EnvVar) -> Binding<String> {
        Binding(
            get: { model.rows.first(where: { $0.id == row.id })?.key ?? row.key },
            set: { newValue in
                if let i = model.rows.firstIndex(where: { $0.id == row.id }) { model.rows[i].key = newValue }
            }
        )
    }

    private func valueBinding(_ row: EnvVar) -> Binding<String> {
        Binding(
            get: { model.rows.first(where: { $0.id == row.id })?.value ?? row.value },
            set: { newValue in
                if let i = model.rows.firstIndex(where: { $0.id == row.id }) { model.rows[i].value = newValue }
            }
        )
    }

    private func notice(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.10))
    }
}
