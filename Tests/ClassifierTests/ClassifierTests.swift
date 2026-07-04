import Testing
import Foundation
@testable import Classifier
import Model

@Suite("EnvClassifier")
struct ClassifierTests {
    let rules = ClassificationRule.defaults

    @Test("Default rules classify common filenames")
    func defaults() {
        #expect(EnvClassifier.classify(fileName: ".env", rules: rules) == .development)
        #expect(EnvClassifier.classify(fileName: ".env.development", rules: rules) == .development)
        #expect(EnvClassifier.classify(fileName: ".env.dev", rules: rules) == .development)
        #expect(EnvClassifier.classify(fileName: ".env.staging", rules: rules) == .staging)
        #expect(EnvClassifier.classify(fileName: ".env.stag", rules: rules) == .staging)
        #expect(EnvClassifier.classify(fileName: ".env.production", rules: rules) == .production)
        #expect(EnvClassifier.classify(fileName: ".env.prod", rules: rules) == .production)
    }

    @Test("Unmatched filenames fall into .other")
    func unmatched() {
        #expect(EnvClassifier.classify(fileName: ".env.local", rules: rules) == .other)
        #expect(EnvClassifier.classify(fileName: ".env.test", rules: rules) == .other)
    }

    @Test("First matching rule wins (order matters)")
    func firstMatchWins() {
        // A catch-all dev rule placed first captures everything.
        let ordered = [
            ClassificationRule(pattern: "env", kind: .development),
            ClassificationRule(pattern: "prod", kind: .production),
        ]
        #expect(EnvClassifier.classify(fileName: ".env.production", rules: ordered) == .development)
    }

    @Test("Disabled rules are skipped")
    func disabledSkipped() {
        let ruleset = [
            ClassificationRule(pattern: "prod", kind: .production, isEnabled: false),
            ClassificationRule(pattern: "prod", kind: .staging, isEnabled: true),
        ]
        #expect(EnvClassifier.classify(fileName: ".env.production", rules: ruleset) == .staging)
    }

    @Test("Invalid regex never matches instead of crashing")
    func invalidRegex() {
        let ruleset = [ClassificationRule(pattern: "[unterminated", kind: .production)]
        #expect(EnvClassifier.classify(fileName: ".env.production", rules: ruleset) == .other)
    }

    @Test("Classification is case-insensitive")
    func caseInsensitive() {
        #expect(EnvClassifier.classify(fileName: ".env.PRODUCTION", rules: rules) == .production)
    }
}
