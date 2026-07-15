import Foundation
import Model

// Serialization: turning an `EnvDocument` back into text. Unchanged entries render
// their original `raw` line verbatim (byte-stable); edited/new entries are rendered
// from their fields with quoting chosen to round-trip the value safely.
extension EnvParser {

    // MARK: Serializing

    /// The document's full text, reproducing the original line endings and
    /// trailing-newline behavior.
    public static func serialize(_ document: EnvDocument) -> String {
        let body = document.lines.map(render).joined(separator: document.lineEnding)
        return document.hasTrailingNewline ? body + document.lineEnding : body
    }

    /// Writes the document to disk (UTF-8). Backup-on-save (`.env.bak`) is handled by the
    /// higher-level save service so this stays a pure serializer.
    public static func write(_ document: EnvDocument, to url: URL) throws {
        try serialize(document).write(to: url, atomically: true, encoding: .utf8)
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

    /// Render a value in its (remembered) quote style. A single-quoted value that now
    /// contains a `'`, or an unquoted value that gained whitespace/`#`/quotes, is
    /// promoted to double quotes so the file still parses back to the same value.
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
