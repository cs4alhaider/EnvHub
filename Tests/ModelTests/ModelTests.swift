import Testing
import Foundation
@testable import Model

@Suite("Model value types")
struct ModelTests {
    @Test("EnvKind has four cases, ordered with titles")
    func envKind() {
        #expect(EnvKind.allCases.count == 4)
        #expect(EnvKind.development.sortOrder < EnvKind.production.sortOrder)
        #expect(EnvKind.production.title == "Production")
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
        #expect(kinds == [.production, .staging, .development])
    }
}
