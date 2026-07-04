import Testing
import Foundation
@testable import Parser
import Model

@Suite("EnvParser")
struct ParserTests {
    let sample = """
    # Database config
    DATABASE_URL=postgres://localhost/dev

    export API_KEY="s3cr3t value"
    PORT=3000 # the port
    QUOTED='single quoted'
    DUP=1
    DUP=2
    """

    // MARK: Round-trip fidelity

    @Test("Round-trips a rich file byte-for-byte")
    func roundTrip() {
        let doc = EnvParser.parse(sample)
        #expect(EnvParser.serialize(doc) == sample)
    }

    @Test("Empty, newline-only, and no-trailing-newline files round-trip")
    func edgeFiles() {
        #expect(EnvParser.serialize(EnvParser.parse("")) == "")
        #expect(EnvParser.serialize(EnvParser.parse("\n")) == "\n")
        #expect(EnvParser.serialize(EnvParser.parse("A=1")) == "A=1")
        #expect(EnvParser.serialize(EnvParser.parse("A=1\n")) == "A=1\n")
    }

    @Test("CRLF line endings are preserved")
    func crlf() {
        let text = "A=1\r\n# c\r\nB=2\r\n"
        #expect(EnvParser.serialize(EnvParser.parse(text)) == text)
    }

    // MARK: Extraction

    @Test("Extracts keys, values, quote styles, export prefixes, inline comments")
    func extraction() {
        let doc = EnvParser.parse(sample)
        func entry(_ key: String) -> EnvEntry? { doc.entries.first { $0.key == key } }

        #expect(entry("DATABASE_URL")?.value == "postgres://localhost/dev")
        #expect(entry("DATABASE_URL")?.quote == QuoteStyle.none)

        #expect(entry("API_KEY")?.value == "s3cr3t value")
        #expect(entry("API_KEY")?.quote == .double)
        #expect(entry("API_KEY")?.hasExport == true)

        #expect(entry("PORT")?.value == "3000")
        #expect(entry("PORT")?.inlineComment == " # the port")

        #expect(entry("QUOTED")?.value == "single quoted")
        #expect(entry("QUOTED")?.quote == .single)
    }

    // MARK: Diagnostics

    @Test("Flags duplicate keys")
    func duplicates() {
        let doc = EnvParser.parse(sample)
        #expect(doc.duplicateKeys() == ["DUP"])
        #expect(doc.diagnostics.contains { $0.kind == .duplicateKey && $0.key == "DUP" })
    }

    @Test("Flags malformed lines but keeps them and stays round-trip stable")
    func malformed() {
        let text = "NOEQUALS\n=novalue\nOK=1"
        let doc = EnvParser.parse(text)
        let kinds = Set(doc.diagnostics.map(\.kind))
        #expect(kinds.contains(.missingEquals))
        #expect(kinds.contains(.emptyKey))
        #expect(doc.entries.count == 1)
        #expect(EnvParser.serialize(doc) == text)
    }

    @Test("Flags unbalanced quotes but keeps the entry editable")
    func unbalanced() {
        let doc = EnvParser.parse("TOKEN=\"oops")
        #expect(doc.entries.first?.issue == .unbalancedQuotes)
        #expect(doc.diagnostics.contains { $0.kind == .unbalancedQuotes })
        #expect(EnvParser.serialize(doc) == "TOKEN=\"oops")
    }

    @Test("A '#' without preceding whitespace is part of an unquoted value")
    func hashInValue() {
        let doc = EnvParser.parse("PASS=p#ssword")
        #expect(doc.entries.first?.value == "p#ssword")
        #expect(doc.entries.first?.inlineComment == nil)
    }

    // MARK: Editing

    @Test("Editing one value rewrites only that line")
    func editValue() {
        let doc = EnvParser.parse("# c\nA=1\nB=2\n")
        var vars = doc.variables
        vars[vars.firstIndex { $0.key == "B" }!].value = "22"
        let edited = EnvParser.applyEdits(to: doc, variables: vars)
        #expect(EnvParser.serialize(edited) == "# c\nA=1\nB=22\n")
    }

    @Test("Adding and deleting variables")
    func addDelete() {
        let doc = EnvParser.parse("A=1\nB=2\n")
        var vars = doc.variables
        vars.removeAll { $0.key == "A" }
        vars.append(EnvVar(key: "C", value: "3"))
        let edited = EnvParser.applyEdits(to: doc, variables: vars)
        #expect(EnvParser.serialize(edited) == "B=2\nC=3\n")
    }

    @Test("A new value containing spaces is quoted")
    func quotingNew() {
        let doc = EnvParser.parse("")
        let edited = EnvParser.applyEdits(to: doc, variables: [EnvVar(key: "MSG", value: "hello world")])
        #expect(EnvParser.serialize(edited) == "MSG=\"hello world\"")
    }

    @Test("Double-quote escapes expand on read and re-escape on edit")
    func escapes() {
        let doc = EnvParser.parse("A=\"line1\\nline2\"")
        #expect(doc.entries.first?.value == "line1\nline2")
        // Unchanged → byte-stable
        #expect(EnvParser.serialize(doc) == "A=\"line1\\nline2\"")
        // Edited → symmetric re-escaping
        var vars = doc.variables
        vars[0].value = "x\ty"
        let edited = EnvParser.applyEdits(to: doc, variables: vars)
        #expect(EnvParser.serialize(edited) == "A=\"x\\ty\"")
    }
}
