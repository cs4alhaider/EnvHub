import Testing
import Foundation
@testable import Model

@Suite("Model value types")
struct ModelTests {
    @Test("EnvKind has six cases, ordered with titles")
    func envKind() {
        #expect(EnvKind.allCases.count == 6)
        #expect(EnvKind.development.sortOrder < EnvKind.production.sortOrder)
        #expect(EnvKind.production.sortOrder < EnvKind.local.sortOrder)
        #expect(EnvKind.local.sortOrder < EnvKind.example.sortOrder)
        #expect(EnvKind.production.title == "Production")
        #expect(EnvKind.example.title == "Example")
    }

    @Test("Only example files are safe to track in git")
    func safeToTrack() {
        #expect(EnvKind.example.isSafeToTrack)
        for kind in EnvKind.allCases where kind != .example {
            #expect(!kind.isSafeToTrack)
        }
    }

    @Test("Project defaults its name to the folder name")
    func projectName() {
        let p = Project(path: URL(filePath: "/tmp/acme-api"))
        #expect(p.name == "acme-api")
    }

    @Test("Project groups distinct environments in display order")
    func environments() {
        let files = [
            EnvFile(path: URL(filePath: "/p/.env.production"), kind: .production),
            EnvFile(path: URL(filePath: "/p/.env"), kind: .development),
        ]
        let p = Project(path: URL(filePath: "/p"), files: files)
        #expect(p.environments == [.development, .production])
    }

    @Test("Default scan config carries the shipped exclusions and patterns")
    func scanDefaults() {
        #expect(ScanConfig.default.exclusions.contains("node_modules"))
        #expect(ScanConfig.default.filenamePatterns == [".env", ".env.*"])
    }

    @Test("Default classification rules cover prod/staging/dev in order")
    func ruleDefaults() {
        let kinds = ClassificationRule.defaults.map(\.kind)
        #expect(kinds == [.example, .local, .production, .staging, .development])
        // The legacy set is frozen — it exists only so stored defaults can be
        // recognized and upgraded.
        #expect(ClassificationRule.legacyDefaults.map(\.kind) == [.production, .staging, .development])
    }
}
