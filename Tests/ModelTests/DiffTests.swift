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
