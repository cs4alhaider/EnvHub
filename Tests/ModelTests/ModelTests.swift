import Testing
import Foundation
@testable import Model

@Suite("Model value types")
struct ModelTests {
    @Test("Built-in catalog titles and orders the shipped environments")
    func builtinCatalog() {
        let catalog = EnvironmentCatalog.builtin
        #expect(catalog.kinds.count == 6)
        #expect(catalog.sortIndex(for: .development) < catalog.sortIndex(for: .production))
        #expect(catalog.sortIndex(for: .production) < catalog.sortIndex(for: .local))
        #expect(catalog.title(for: .production) == "Production")
        #expect(catalog.title(for: .example) == "Example")
    }

    @Test("Only example files are safe to track in git")
    func safeToTrack() {
        let catalog = EnvironmentCatalog.builtin
        #expect(catalog.isSafeToTrack(.example))
        for kind in catalog.kinds where kind != .example {
            #expect(!catalog.isSafeToTrack(kind))
        }
    }

    @Test("Custom environment: slug, title, color, ordering, and graceful fallback")
    func customEnvironment() {
        // A user adds "UAT" between staging and production.
        let uat = EnvKind.slug(from: "UAT")
        #expect(uat.rawValue == "uat")
        #expect(EnvKind.slug(from: "Pre Prod!").rawValue == "pre-prod")

        var defs = EnvironmentDefinition.defaults
        defs.insert(EnvironmentDefinition(kind: uat, title: "UAT", color: .teal), at: 2)
        let catalog = EnvironmentCatalog(definitions: defs)
        #expect(catalog.title(for: uat) == "UAT")
        #expect(catalog.color(for: uat) == .teal)
        #expect(catalog.sortIndex(for: uat) < catalog.sortIndex(for: .production))

        // A kind with no definition degrades gracefully (capitalized slug, gray, last).
        let orphan = EnvKind(rawValue: "qa")
        #expect(catalog.title(for: orphan) == "Qa")
        #expect(catalog.color(for: orphan) == .gray)
        #expect(catalog.sortIndex(for: orphan) >= catalog.definitions.count)
    }

    @Test("EnvKind encodes as a bare string (backward compatible with the old enum)")
    func envKindCodable() throws {
        let data = try JSONEncoder().encode(EnvKind.production)
        #expect(String(decoding: data, as: UTF8.self) == "\"production\"")
        #expect(try JSONDecoder().decode(EnvKind.self, from: Data("\"uat\"".utf8)) == EnvKind(rawValue: "uat"))
    }

    @Test("Catalog always contains the non-deletable Other bucket")
    func otherAlwaysPresent() {
        let catalog = EnvironmentCatalog(definitions: [
            EnvironmentDefinition(kind: .production, title: "Prod", color: .red)
        ])
        #expect(catalog.kinds.contains(.other))
        #expect(catalog.title(for: .other) == "Other")
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
        #expect(p.environments() == [.development, .production])
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
