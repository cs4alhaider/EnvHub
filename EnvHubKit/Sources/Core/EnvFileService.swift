import Foundation
import Parser

/// Loads and saves `.env` files for the app and CLI. Saving performs the required
/// backup-on-save: a `.bak` copy of the *current* on-disk file is written first, then
/// the new content is written to the real file — with comments and blank lines
/// preserved (that fidelity comes from `EnvParser`).
public enum EnvFileService {
    /// Parses a `.env` file from disk into a faithful document.
    public static func load(_ url: URL) throws -> EnvDocument {
        try EnvParser.read(contentsOf: url)
    }

    /// Parse/serialize passthroughs so the app (which links only `Core`) can round-trip
    /// text without importing the internal `Parser` target — used by the raw editor.
    public static func parse(_ text: String) -> EnvDocument { EnvParser.parse(text) }
    public static func serialize(_ document: EnvDocument) -> String { EnvParser.serialize(document) }

    /// The current on-disk-equivalent text for a document plus pending edits.
    public static func currentText(document: EnvDocument, variables: [EnvVar]) -> String {
        EnvParser.serialize(EnvParser.applyEdits(to: document, variables: variables))
    }

    /// The backup location for a file: the same name with `.bak` appended
    /// (`.env` → `.env.bak`, `.env.production` → `.env.production.bak`).
    public static func backupURL(for url: URL) -> URL {
        url.deletingLastPathComponent().appendingPathComponent(url.lastPathComponent + ".bak")
    }

    /// Copy the existing on-disk file (if any) to its `.bak` location.
    private static func backup(_ url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        let backup = backupURL(for: url)
        if fm.fileExists(atPath: backup.path(percentEncoded: false)) {
            try fm.removeItem(at: backup)
        }
        try fm.copyItem(at: url, to: backup)
    }

    /// Backup-on-save, then write the serialized document.
    public static func save(_ document: EnvDocument, to url: URL) throws {
        try backup(url)
        try EnvParser.write(document, to: url)
    }

    /// Backup-on-save, then write raw text verbatim (used by the developer/raw view).
    public static func save(text: String, to url: URL) throws {
        try backup(url)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Reconciles edited variables onto the loaded document (byte-stable for untouched
    /// lines) and saves. Returns the reconciled document.
    @discardableResult
    public static func save(original: EnvDocument, variables: [EnvVar], to url: URL) throws -> EnvDocument {
        let updated = EnvParser.applyEdits(to: original, variables: variables)
        try save(updated, to: url)
        return updated
    }

    /// Create a new env file: blank, or seeded with the keys of an existing file
    /// (values cleared, per-key comments kept — handy for `.env.example`).
    /// Refuses to overwrite.
    public static func create(at url: URL, copyingKeysFrom source: URL? = nil) throws {
        guard !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            throw EnvExportError.fileExists(url)
        }
        var text = ""
        if let source, let doc = try? EnvParser.read(contentsOf: source) {
            let cleared = doc.variables.map { EnvVar(key: $0.key, value: "", comment: $0.comment) }
            text = EnvParser.serialize(EnvParser.applyEdits(to: EnvDocument(lines: []), variables: cleared))
            if !text.isEmpty && !text.hasSuffix("\n") { text += "\n" }
        }
        try text.write(to: url, atomically: true, encoding: .utf8)
    }
}
