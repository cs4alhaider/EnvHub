//
//  EnvFileEditorModel.swift
//  EnvHub
//
//  View-model for one open .env file: a structured table view and a raw "developer"
//  text view, dirty tracking, per-row masking, inline validation, and backup-then-write
//  Save (via Core).
//

import SwiftUI
import Core

@MainActor
@Observable
final class EnvFileEditorModel {
    let fileURL: URL
    private(set) var document: EnvDocument
    var rows: [EnvVar]
    private var savedRows: [EnvVar]

    enum EditorMode: String, CaseIterable { case table, raw }
    var mode: EditorMode = .table
    var rawText: String
    private var savedText: String

    var revealAll: Bool
    var revealedRows: Set<UUID> = []

    var loadError: String?
    var saveError: String?

    enum RowStatus: Equatable {
        case ok
        case warning(String)
    }

    init(fileURL: URL, maskByDefault: Bool) {
        self.fileURL = fileURL
        self.revealAll = !maskByDefault
        do {
            let doc = try EnvFileService.load(fileURL)
            self.document = doc
            self.rows = doc.variables
            self.savedRows = doc.variables
            let text = EnvFileService.serialize(doc)
            self.rawText = text
            self.savedText = text
        } catch {
            self.document = EnvDocument(lines: [])
            self.rows = []
            self.savedRows = []
            self.rawText = ""
            self.savedText = ""
            self.loadError = error.localizedDescription
        }
    }

    // MARK: Derived state

    var isDirty: Bool { mode == .raw ? rawText != savedText : rows != savedRows }

    var variableCount: Int { rows.count }

    var duplicateKeys: Set<String> {
        var counts: [String: Int] = [:]
        for r in rows where !r.key.isEmpty { counts[r.key, default: 0] += 1 }
        return Set(counts.filter { $0.value > 1 }.map(\.key))
    }

    var documentIssueCount: Int {
        document.diagnostics.filter { $0.kind != .duplicateKey }.count
    }

    func status(for row: EnvVar) -> RowStatus {
        if row.key.trimmingCharacters(in: .whitespaces).isEmpty { return .warning("Empty key") }
        if duplicateKeys.contains(row.key) { return .warning("Duplicate key “\(row.key)”") }
        return .ok
    }

    /// The current text regardless of mode (used by Copy).
    var currentText: String {
        mode == .raw ? rawText : EnvFileService.currentText(document: document, variables: rows)
    }

    // MARK: Masking

    func isRevealed(_ id: UUID) -> Bool { revealAll || revealedRows.contains(id) }

    func toggleReveal(_ id: UUID) {
        if revealedRows.contains(id) { revealedRows.remove(id) } else { revealedRows.insert(id) }
    }

    // MARK: Mode

    func setMode(_ newMode: EditorMode) {
        guard newMode != mode else { return }
        if newMode == .raw {
            rawText = EnvFileService.currentText(document: document, variables: rows)
        } else {
            let doc = EnvFileService.parse(rawText)
            document = doc
            rows = doc.variables
        }
        mode = newMode
    }

    // MARK: Editing

    @discardableResult
    func addRow() -> UUID {
        let v = EnvVar(key: "", value: "")
        rows.append(v)
        return v.id
    }

    func deleteRows(_ ids: Set<UUID>) {
        rows.removeAll { ids.contains($0.id) }
    }

    func revert() {
        rows = savedRows
        rawText = savedText
    }

    /// Backup-on-save, then write. Reconciliation keeps untouched lines byte-stable.
    func save() {
        do {
            if mode == .raw {
                try EnvFileService.save(text: rawText, to: fileURL)
                let doc = EnvFileService.parse(rawText)
                document = doc
                rows = doc.variables
                savedRows = rows
                savedText = rawText
            } else {
                let updated = try EnvFileService.save(original: document, variables: rows, to: fileURL)
                document = updated
                savedRows = rows
                savedText = EnvFileService.serialize(updated)
                rawText = savedText
            }
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }
}
