import Foundation
import Model

/// Reads and writes `.env` files while preserving comments and blank lines, keeping
/// untouched lines byte-stable, and flagging duplicate keys and malformed lines.
///
/// The round-trip contract: `serialize(parse(text)) == text` for any input, because
/// every parsed line retains its original raw text. Edits are applied with
/// `applyEdits(to:variables:)`, which re-serializes only the lines that actually
/// changed and leaves everything else byte-for-byte identical.
public enum EnvParser {

    // MARK: Parsing

    public static func parse(_ text: String) -> EnvDocument {
        if text.isEmpty {
            return EnvDocument(lines: [], lineEnding: "\n", hasTrailingNewline: false)
        }

        let hasCRLF = text.contains("\r\n")
        let ending = hasCRLF ? "\r\n" : "\n"
        let hasTrailingNewline = text.hasSuffix("\n")

        var rawLines = text.components(separatedBy: "\n")
        if hasTrailingNewline { rawLines.removeLast() }  // drop the empty element after the final "\n"

        var lines: [EnvLine] = []
        lines.reserveCapacity(rawLines.count)
        for (index, piece) in rawLines.enumerated() {
            var raw = piece
            if hasCRLF, raw.hasSuffix("\r") { raw.removeLast() }
            lines.append(classify(raw, lineNumber: index + 1))
        }
        return EnvDocument(lines: lines, lineEnding: ending, hasTrailingNewline: hasTrailingNewline)
    }

    public static func read(contentsOf url: URL) throws -> EnvDocument {
        let data = try Data(contentsOf: url)
        return parse(String(decoding: data, as: UTF8.self))
    }

    // MARK: Serializing

    public static func serialize(_ document: EnvDocument) -> String {
        let body = document.lines.map(render).joined(separator: document.lineEnding)
        return document.hasTrailingNewline ? body + document.lineEnding : body
    }

    /// Writes the document to disk (UTF-8). Backup-on-save (`.env.bak`) is handled by the
    /// higher-level save service so this stays a pure serializer.
    public static func write(_ document: EnvDocument, to url: URL) throws {
        try serialize(document).write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: Applying edits

    /// Reconciles an edited set of variables back onto the original document. Unchanged
    /// entries keep their `raw` (byte-stable); changed entries are re-serialized;
    /// removed variables drop their line; new variables are appended as fresh entries.
    /// Comments, blanks, and malformed lines are always preserved.
    public static func applyEdits(to document: EnvDocument, variables: [EnvVar]) -> EnvDocument {
        var byID: [UUID: EnvVar] = [:]
        for v in variables { byID[v.id] = v }

        var newLines: [EnvLine] = []
        var seen = Set<UUID>()

        for line in document.lines {
            switch line {
            case .entry(let entry):
                guard let v = byID[entry.id] else { continue }  // deleted
                seen.insert(entry.id)
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
            newLines.append(.entry(EnvEntry(id: v.id, key: v.key, value: v.value)))
        }

        var doc = document
        doc.lines = newLines
        return doc
    }

    // MARK: - Line classification

    private static func classify(_ raw: String, lineNumber: Int) -> EnvLine {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .blank }
        if trimmed.hasPrefix("#") { return .comment(raw) }
        return parseEntry(raw, lineNumber: lineNumber)
    }

    private static func parseEntry(_ raw: String, lineNumber: Int) -> EnvLine {
        var working = Substring(raw)
        var hasExport = false
        if let r = raw.range(of: #"^\s*export\s+"#, options: .regularExpression) {
            hasExport = true
            working = raw[r.upperBound...]
        }

        guard let eq = working.firstIndex(of: "=") else {
            return .malformed(raw, .missingEquals)
        }
        let key = String(working[..<eq]).trimmingCharacters(in: .whitespaces)
        if key.isEmpty { return .malformed(raw, .emptyKey) }

        let valuePart = working[working.index(after: eq)...]
        let parsed = parseValue(String(valuePart))
        return .entry(EnvEntry(
            key: key,
            value: parsed.value,
            quote: parsed.quote,
            hasExport: hasExport,
            inlineComment: parsed.inlineComment,
            issue: parsed.issue,
            raw: raw,
            originalLineNumber: lineNumber
        ))
    }

    private struct ParsedValue {
        var value: String
        var quote: QuoteStyle
        var inlineComment: String?
        var issue: EnvEntryIssue?
    }

    /// Parses everything after the first `=`.
    private static func parseValue(_ part: String) -> ParsedValue {
        // dotenv trims leading whitespace before the value.
        let body = Substring(part).drop { $0 == " " || $0 == "\t" }
        guard let first = body.first else {
            return ParsedValue(value: "", quote: .none, inlineComment: nil, issue: nil)
        }

        if first == "\"" || first == "'" {
            return parseQuotedValue(body, quoteChar: first)
        }
        return parseUnquotedValue(String(body))
    }

    private static func parseQuotedValue(_ body: Substring, quoteChar: Character) -> ParsedValue {
        let style: QuoteStyle = quoteChar == "\"" ? .double : .single
        let supportsEscapes = quoteChar == "\""

        var value = ""
        var idx = body.index(after: body.startIndex)
        var closed = false
        while idx < body.endIndex {
            let c = body[idx]
            if supportsEscapes, c == "\\" {
                let next = body.index(after: idx)
                if next < body.endIndex {
                    value.append(unescape(body[next]))
                    idx = body.index(after: next)
                    continue
                }
            }
            if c == quoteChar {
                closed = true
                idx = body.index(after: idx)
                break
            }
            value.append(c)
            idx = body.index(after: idx)
        }

        if !closed {
            return ParsedValue(value: value, quote: style, inlineComment: nil, issue: .unbalancedQuotes)
        }
        let remainder = String(body[idx...])
        return ParsedValue(value: value, quote: style, inlineComment: inlineComment(from: remainder), issue: nil)
    }

    private static func parseUnquotedValue(_ s: String) -> ParsedValue {
        if let commentStart = unquotedCommentStart(s) {
            let value = String(s[s.startIndex..<commentStart]).trimmingCharacters(in: .whitespaces)
            let comment = String(s[commentStart...])
            return ParsedValue(value: value, quote: .none, inlineComment: comment, issue: nil)
        }
        return ParsedValue(value: s.trimmingCharacters(in: .whitespaces), quote: .none, inlineComment: nil, issue: nil)
    }

    /// For an unquoted value, an inline comment begins at a `#` preceded by whitespace.
    /// Returns the index of the start of that whitespace run so the comment (with its
    /// leading spaces) is preserved for byte-stable rewrites.
    private static func unquotedCommentStart(_ s: String) -> String.Index? {
        var whitespaceRunStart: String.Index?
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c == " " || c == "\t" {
                if whitespaceRunStart == nil { whitespaceRunStart = i }
            } else if c == "#" {
                if let ws = whitespaceRunStart { return ws }
            } else {
                whitespaceRunStart = nil
            }
            i = s.index(after: i)
        }
        return nil
    }

    /// The trailing text after a closing quote is an inline comment if it contains `#`;
    /// otherwise it's dropped (trailing whitespace is not significant).
    private static func inlineComment(from remainder: String) -> String? {
        remainder.contains("#") ? remainder : nil
    }

    private static func unescape(_ c: Character) -> Character {
        switch c {
        case "n": "\n"
        case "t": "\t"
        case "r": "\r"
        case "\\": "\\"
        case "\"": "\""
        case "'": "'"
        default: c
        }
    }

    // MARK: - Rendering a single line

    private static func render(_ line: EnvLine) -> String {
        switch line {
        case .blank: ""
        case .comment(let raw): raw
        case .malformed(let raw, _): raw
        case .entry(let e): renderEntry(e)
        }
    }

    private static func renderEntry(_ e: EnvEntry) -> String {
        if let raw = e.raw { return raw }  // unchanged → byte-stable
        var s = ""
        if e.hasExport { s += "export " }
        s += e.key + "=" + renderValue(e.value, quote: e.quote)
        if let comment = e.inlineComment { s += comment }
        return s
    }

    private static func renderValue(_ value: String, quote: QuoteStyle) -> String {
        switch quote {
        case .double:
            return "\"" + escapeDouble(value) + "\""
        case .single:
            return value.contains("'") ? "\"" + escapeDouble(value) + "\"" : "'" + value + "'"
        case .none:
            return needsQuoting(value) ? "\"" + escapeDouble(value) + "\"" : value
        }
    }

    private static func needsQuoting(_ v: String) -> Bool {
        guard !v.isEmpty else { return false }
        if v.first == " " || v.last == " " { return true }
        return v.contains { " \t\n\r#\"'".contains($0) }
    }

    private static func escapeDouble(_ v: String) -> String {
        var out = ""
        out.reserveCapacity(v.count)
        for c in v {
            switch c {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\r": out += "\\r"
            default: out.append(c)
            }
        }
        return out
    }
}
