import Testing
@testable import Model

@Suite("EnvDiff")
struct DiffTests {
    @Test("Classifies same / different / left-only / right-only")
    func compare() {
        let left = [
            EnvVar(key: "SHARED", value: "1"),
            EnvVar(key: "CHANGED", value: "dev"),
            EnvVar(key: "ONLY_LEFT", value: "x"),
        ]
        let right = [
            EnvVar(key: "SHARED", value: "1"),
            EnvVar(key: "CHANGED", value: "prod"),
            EnvVar(key: "ONLY_RIGHT", value: "y"),
        ]
        let diff = EnvDiff.compare(left: left, right: right)
        let byKey = Dictionary(uniqueKeysWithValues: diff.map { ($0.key, $0) })

        #expect(byKey["SHARED"]?.state == .same)
        #expect(byKey["CHANGED"]?.state == .different)
        #expect(byKey["CHANGED"]?.leftValue == "dev")
        #expect(byKey["CHANGED"]?.rightValue == "prod")
        #expect(byKey["ONLY_LEFT"]?.state == .leftOnly)
        #expect(byKey["ONLY_LEFT"]?.rightValue == nil)
        #expect(byKey["ONLY_RIGHT"]?.state == .rightOnly)
    }

    @Test("Results are sorted by key")
    func sorted() {
        let diff = EnvDiff.compare(
            left: [EnvVar(key: "B", value: "1"), EnvVar(key: "A", value: "1")],
            right: []
        )
        #expect(diff.map(\.key) == ["A", "B"])
    }

    @Test("Changes: added / removed / value edit / comment edit, in file order")
    func changes() {
        let old = [
            EnvVar(key: "KEEP", value: "1"),
            EnvVar(key: "EDIT", value: "a", comment: "old note"),
            EnvVar(key: "GONE", value: "x"),
        ]
        let new = [
            EnvVar(key: "KEEP", value: "1"),
            EnvVar(key: "EDIT", value: "b", comment: "new note"),
            EnvVar(key: "FRESH", value: "y"),
        ]
        let changes = EnvDiff.changes(from: old, to: new)
        #expect(changes.map(\.key) == ["EDIT", "FRESH", "GONE"])

        let edit = changes[0]
        #expect(edit.kind == .modified)
        #expect(edit.valueChanged && edit.commentChanged)
        #expect(edit.oldValue == "a" && edit.newValue == "b")
        #expect(edit.oldComment == "old note" && edit.newComment == "new note")

        #expect(changes[1].kind == .added)
        #expect(changes[1].newValue == "y")
        #expect(changes[2].kind == .removed)
        #expect(changes[2].oldValue == "x")
    }

    @Test("Comment-only edits count as modified")
    func commentOnlyChange() {
        let changes = EnvDiff.changes(
            from: [EnvVar(key: "A", value: "1", comment: "before")],
            to: [EnvVar(key: "A", value: "1", comment: "after")]
        )
        #expect(changes.count == 1)
        #expect(changes[0].kind == .modified)
        #expect(!changes[0].valueChanged)
        #expect(changes[0].commentChanged)
    }

    @Test("No edits → no changes; duplicates collapse last-wins; empty keys ignored")
    func changesEdgeCases() {
        #expect(EnvDiff.changes(
            from: [EnvVar(key: "A", value: "1")],
            to: [EnvVar(key: "A", value: "1")]
        ).isEmpty)

        let dup = EnvDiff.changes(
            from: [EnvVar(key: "A", value: "1")],
            to: [EnvVar(key: "A", value: "stale"), EnvVar(key: "A", value: "2")]
        )
        #expect(dup.count == 1)
        #expect(dup[0].kind == .modified)
        #expect(dup[0].newValue == "2")

        #expect(EnvDiff.changes(from: [], to: [EnvVar(key: "", value: "ignored")]).isEmpty)
    }

    @Test("Summary counts each category")
    func summary() {
        let diff = EnvDiff.compare(
            left: [EnvVar(key: "S", value: "1"), EnvVar(key: "D", value: "a"), EnvVar(key: "L", value: "x")],
            right: [EnvVar(key: "S", value: "1"), EnvVar(key: "D", value: "b"), EnvVar(key: "R", value: "y")]
        )
        let s = EnvDiff.summary(diff)
        #expect(s.same == 1)
        #expect(s.different == 1)
        #expect(s.leftOnly == 1)
        #expect(s.rightOnly == 1)
    }
}
