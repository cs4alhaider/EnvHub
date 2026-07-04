import Foundation
import Model

// Edit reconciliation: the bridge between the app's editable `[EnvVar]` rows and the
// faithful on-disk document.
extension EnvParser {

    /// Reconciles an edited set of variables back onto the original document.
    ///
    /// Matching is by the stable `EnvVar.id` that `EnvDocument.variables` handed out at
    /// parse time, which is what makes the rules below possible:
    /// - **Unchanged** entries keep their `raw` line → written back byte-for-byte.
    /// - **Changed** entries get `raw` cleared → re-serialized (and any stale
    ///   `unbalancedQuotes` issue cleared, since the value was re-entered).
    /// - **Removed** variables drop their line entirely.
    /// - **New** variables (ids not present in the document) are appended at the end.
    ///
    /// Comments: the **single comment line directly above** an entry is that entry's
    /// editable `comment` (mirroring `EnvDocument.variables`):
    /// - Untouched comments stay byte-stable (the original line is kept verbatim).
    /// - A changed comment re-renders that one line as `# text`.
    /// - A newly added comment inserts a `# text` line above its entry; a cleared
    ///   comment removes the line; a deleted variable takes its comment line with it.
    /// - All other comment, blank, and malformed lines are always preserved in place.
    public static func applyEdits(to document: EnvDocument, variables: [EnvVar]) -> EnvDocument {
        var byID: [UUID: EnvVar] = [:]
        for v in variables { byID[v.id] = v }

        var newLines: [EnvLine] = []
        var seen = Set<UUID>()
        let lines = document.lines

        for (index, line) in lines.enumerated() {
            switch line {
            case .entry(let entry):
                // The adjacent comment line (if any) was appended to `newLines` on the
                // previous iteration, so it is exactly `newLines.last` here.
                var hasCommentLineAbove = false
                var originalComment: String?
                if index > 0, case .comment = lines[index - 1] {
                    hasCommentLineAbove = true
                    originalComment = normalizedComment(lines[index - 1].commentText)
                }

                guard let v = byID[entry.id] else {
                    // Variable deleted — its descriptive comment goes with it.
                    if hasCommentLineAbove { newLines.removeLast() }
                    continue
                }
                seen.insert(entry.id)

                let editedComment = normalizedComment(v.comment)
                if editedComment != originalComment {
                    if hasCommentLineAbove { newLines.removeLast() }
                    if let editedComment { newLines.append(.comment("# " + editedComment)) }
                }

                if v.key == entry.key && v.value == entry.value {
                    newLines.append(.entry(entry))              // untouched → keep raw
                } else {
                    var updated = entry
                    updated.key = v.key
                    updated.value = v.value
                    updated.issue = nil
                    updated.raw = nil                           // force re-serialize
                    newLines.append(.entry(updated))
                }
            case .blank, .comment, .malformed:
                newLines.append(line)
            }
        }

        for v in variables where !seen.contains(v.id) {
            if let comment = normalizedComment(v.comment) {
                newLines.append(.comment("# " + comment))
            }
            newLines.append(.entry(EnvEntry(id: v.id, key: v.key, value: v.value)))
        }

        var doc = document
        doc.lines = newLines
        return doc
    }

    /// Comment text as compared/stored: trimmed, with empty collapsing to `nil` so
    /// "no comment" and "spaces only" mean the same thing.
    private static func normalizedComment(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespaces), !trimmed.isEmpty else { return nil }
        return trimmed
    }
}
