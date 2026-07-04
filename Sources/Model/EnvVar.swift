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

    public init(id: UUID = UUID(), key: String, value: String) {
        self.id = id
        self.key = key
        self.value = value
    }
}
