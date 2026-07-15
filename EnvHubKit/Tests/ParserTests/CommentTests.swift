import Testing
import Foundation
@testable import Parser
import Model

/// The comment-column contract: the single comment line directly above an entry is
/// that entry's editable `comment`; everything else about the file stays untouched.
@Suite("EnvParser comments")
struct CommentTests {
    let sample = """
    # Supabase project URL
    VITE_SUPABASE_URL=https://x.supabase.co

    # Anon key
    ## keep secret
    VITE_SUPABASE_ANON_KEY=abc

    LONELY=1
    # trailing comment (attached to nothing)
    """

    @Test("Variables carry the single comment line directly above them")
    func association() {
        let vars = EnvParser.parse(sample).variables
        #expect(vars[0].comment == "Supabase project URL")
        #expect(vars[1].comment == "# keep secret")   // one leading # stripped, the intentional one kept
        #expect(vars[2].comment == nil)               // blank line above LONELY breaks the association
    }

    @Test("Round-trip with untouched variables is byte-stable, comments included")
    func untouchedStable() {
        let doc = EnvParser.parse(sample)
        let out = EnvParser.applyEdits(to: doc, variables: doc.variables)
        #expect(EnvParser.serialize(out) == sample)
    }

    @Test("Editing a comment rewrites only that line")
    func editComment() {
        let doc = EnvParser.parse("# old\nA=1\nB=2\n")
        var vars = doc.variables
        vars[0].comment = "new words"
        #expect(EnvParser.serialize(EnvParser.applyEdits(to: doc, variables: vars)) == "# new words\nA=1\nB=2\n")
    }

    @Test("Adding a comment inserts a # line above the entry")
    func addComment() {
        let doc = EnvParser.parse("A=1\nB=2\n")
        var vars = doc.variables
        vars[1].comment = "b docs"
        #expect(EnvParser.serialize(EnvParser.applyEdits(to: doc, variables: vars)) == "A=1\n# b docs\nB=2\n")
    }

    @Test("Clearing a comment (or blanking it) removes its line")
    func clearComment() {
        let doc = EnvParser.parse("# gone\nA=1\n")
        var vars = doc.variables
        vars[0].comment = nil
        #expect(EnvParser.serialize(EnvParser.applyEdits(to: doc, variables: vars)) == "A=1\n")

        vars = doc.variables
        vars[0].comment = "   "
        #expect(EnvParser.serialize(EnvParser.applyEdits(to: doc, variables: vars)) == "A=1\n")
    }

    @Test("Deleting a variable deletes its comment line with it")
    func deleteTakesComment() {
        let doc = EnvParser.parse("# a docs\nA=1\n# b docs\nB=2\n")
        let vars = doc.variables.filter { $0.key != "A" }
        #expect(EnvParser.serialize(EnvParser.applyEdits(to: doc, variables: vars)) == "# b docs\nB=2\n")
    }

    @Test("A comment separated by a blank line is not attached — and stays put")
    func blankBreaksAssociation() {
        let doc = EnvParser.parse("# header\n\nA=1\n")
        #expect(doc.variables[0].comment == nil)

        var vars = doc.variables
        vars[0].comment = "a docs"
        #expect(EnvParser.serialize(EnvParser.applyEdits(to: doc, variables: vars)) == "# header\n\n# a docs\nA=1\n")
    }

    @Test("New variables append together with their comment")
    func newWithComment() {
        let doc = EnvParser.parse("A=1\n")
        var vars = doc.variables
        vars.append(EnvVar(key: "B", value: "2", comment: "b docs"))
        #expect(EnvParser.serialize(EnvParser.applyEdits(to: doc, variables: vars)) == "A=1\n# b docs\nB=2\n")
    }

    @Test("A value edit keeps its untouched comment line byte-stable")
    func valueEditKeepsComment() {
        let doc = EnvParser.parse("#   spaced   comment\nA=1\n")
        var vars = doc.variables
        vars[0].value = "2"
        #expect(EnvParser.serialize(EnvParser.applyEdits(to: doc, variables: vars)) == "#   spaced   comment\nA=2\n")
    }
}
