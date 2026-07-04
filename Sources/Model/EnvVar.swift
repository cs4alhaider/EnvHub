import Foundation

/// One key/value pair — the unit the structured table editor edits. Identity is a
/// stable `UUID` so the editor can track a row across edits and the writer can
/// reconcile edits back onto the original file (see `EnvParser.applyEdits`).
///
/// Parse-time diagnostics (duplicate / malformed) are *not* stored here; they are
/// derived from the `EnvDocument` so they always reflect the current set of keys.
public struct EnvVar: Identifiable, Sendable, Hashable, Codable {
    public var id: UUID
    public var key: String
    public var value: String

    /// The human text of the **single comment line directly above** this entry in the
    /// file (leading `#` stripped), when present — a blank line breaks the association.
    /// Editable in the editor's Comment column; `EnvParser.applyEdits` writes changes
    /// back as a `# …` line above the entry (and leaves untouched comments byte-stable).
    public var comment: String?

    public init(id: UUID = UUID(), key: String, value: String, comment: String? = nil) {
        self.id = id
        self.key = key
        self.value = value
        self.comment = comment
    }
}
