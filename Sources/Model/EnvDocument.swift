import Foundation

/// How a value was quoted in the source, so edits can re-serialize consistently.
public enum QuoteStyle: String, Sendable, Hashable, Codable {
    case none
    case single
    case double
}

/// A recoverable problem with an otherwise-parseable entry (the line is still an
/// editable key/value, just flagged).
public enum EnvEntryIssue: String, Sendable, Hashable, Codable {
    case unbalancedQuotes
}

/// Why a line could not be parsed as a key/value pair at all (kept verbatim, shown but
/// not editable as a variable).
public enum MalformedReason: String, Sendable, Hashable, Codable {
    case missingEquals
    case emptyKey
}

/// A parsed `KEY=VALUE` entry. Retains enough of the original syntax (`export` prefix,
/// quote style, trailing inline comment) to re-serialize faithfully, plus the original
/// `raw` line so an *unchanged* entry is written back byte-for-byte.
public struct EnvEntry: Identifiable, Sendable, Hashable, Codable {
    public var id: UUID
    public var key: String
    public var value: String
    public var quote: QuoteStyle
    public var hasExport: Bool
    /// Trailing inline comment including its leading whitespace and `#`, e.g. `"  # note"`.
    public var inlineComment: String?
    public var issue: EnvEntryIssue?
    /// The exact original line (without newline). `nil` once edited or freshly created,
    /// which forces re-serialization.
    public var raw: String?
    /// 1-based line number in the source file, when parsed from disk.
    public var originalLineNumber: Int?

    public init(
        id: UUID = UUID(),
        key: String,
        value: String,
        quote: QuoteStyle = .none,
        hasExport: Bool = false,
        inlineComment: String? = nil,
        issue: EnvEntryIssue? = nil,
        raw: String? = nil,
        originalLineNumber: Int? = nil
    ) {
        self.id = id
        self.key = key
        self.value = value
        self.quote = quote
        self.hasExport = hasExport
        self.inlineComment = inlineComment
        self.issue = issue
        self.raw = raw
        self.originalLineNumber = originalLineNumber
    }
}

/// One physical line in a `.env` file, preserving comments and blanks so the file
/// round-trips faithfully.
public enum EnvLine: Sendable, Hashable, Codable {
    case blank
    case comment(String)             // full raw text, including any leading indentation and `#`
    case entry(EnvEntry)
    case malformed(String, MalformedReason)  // raw text that isn't a valid key/value line
}

/// A faithfully-parsed `.env` file: an ordered list of lines plus the line-ending style
/// and trailing-newline flag needed to reproduce the original bytes.
public struct EnvDocument: Sendable, Hashable, Codable {
    public var lines: [EnvLine]
    public var lineEnding: String
    public var hasTrailingNewline: Bool

    public init(lines: [EnvLine], lineEnding: String = "\n", hasTrailingNewline: Bool = true) {
        self.lines = lines
        self.lineEnding = lineEnding
        self.hasTrailingNewline = hasTrailingNewline
    }

    /// Just the entry lines, in file order.
    public var entries: [EnvEntry] {
        lines.compactMap { if case .entry(let e) = $0 { e } else { nil } }
    }

    /// The editable key/value units derived from the entries, in file order.
    public var variables: [EnvVar] {
        entries.map { EnvVar(id: $0.id, key: $0.key, value: $0.value) }
    }

    /// Keys that appear on more than one entry line.
    public func duplicateKeys() -> Set<String> {
        var counts: [String: Int] = [:]
        for e in entries { counts[e.key, default: 0] += 1 }
        return Set(counts.filter { $0.value > 1 }.map(\.key))
    }

    /// All inline diagnostics (duplicate keys, malformed lines, unbalanced quotes).
    public var diagnostics: [EnvDiagnostic] {
        let dups = duplicateKeys()
        var result: [EnvDiagnostic] = []
        for line in lines {
            switch line {
            case .entry(let e):
                if dups.contains(e.key) {
                    result.append(EnvDiagnostic(
                        lineNumber: e.originalLineNumber, key: e.key,
                        kind: .duplicateKey, message: "Duplicate key “\(e.key)”"))
                }
                if e.issue == .unbalancedQuotes {
                    result.append(EnvDiagnostic(
                        lineNumber: e.originalLineNumber, key: e.key,
                        kind: .unbalancedQuotes, message: "Unbalanced quotes in “\(e.key)”"))
                }
            case .malformed(_, let reason):
                let kind: EnvDiagnostic.Kind = reason == .missingEquals ? .missingEquals : .emptyKey
                let message = reason == .missingEquals ? "Line has no “=”" : "Line has an empty key"
                result.append(EnvDiagnostic(lineNumber: nil, key: nil, kind: kind, message: message))
            case .blank, .comment:
                break
            }
        }
        return result
    }
}
