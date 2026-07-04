import Testing
import Foundation
import SwiftData
@testable import Core

@MainActor
@Suite("SwiftData persistence")
struct PersistenceTests {
    // Held for the lifetime of each test instance so the in-memory store isn't
    // deallocated out from under its context. Swift Testing makes a fresh instance
    // (and thus a fresh container) per test.
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try EnvHubStore.container(inMemory: true)
    }

    @Test("Container builds in memory with the full schema")
    func containerBuilds() throws {
        #expect(try context.fetch(FetchDescriptor<ProjectRecord>()).isEmpty)
    }

    @Test("Adding a project inserts it and dedupes by path")
    func addProjectDedupes() throws {
        let url = URL(filePath: "/tmp/acme-api")
        #expect(ProjectStore.addProject(at: url, to: context) != nil)
        #expect(ProjectStore.addProject(at: url, to: context) == nil)   // duplicate ignored
        let all = try context.fetch(FetchDescriptor<ProjectRecord>())
        #expect(all.count == 1)
        #expect(all.first?.name == "acme-api")
    }

    @Test("Removing a project forgets it")
    func removeProject() throws {
        let record = try #require(ProjectStore.addProject(at: URL(filePath: "/tmp/x"), to: context))
        ProjectStore.remove(record, from: context)
        #expect(try context.fetch(FetchDescriptor<ProjectRecord>()).isEmpty)
    }

    @Test("addProject dedupes trailing-slash and symlink spellings of the same folder")
    func canonicalDedupe() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appendingPathComponent("envhub-canon-\(UUID().uuidString)")
        let real = base.appendingPathComponent("app")
        try fm.createDirectory(at: real, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        let link = base.appendingPathComponent("app-link")
        try fm.createSymbolicLink(at: link, withDestinationURL: real)

        #expect(ProjectStore.addProject(at: real, to: context) != nil)
        // Same folder, different spellings — all duplicates:
        #expect(ProjectStore.addProject(at: URL(filePath: real.path(percentEncoded: false) + "/"), to: context) == nil)
        #expect(ProjectStore.addProject(at: link, to: context) == nil)
        #expect(try context.fetch(FetchDescriptor<ProjectRecord>()).count == 1)
    }

    @Test("cleanupDuplicates merges same-folder records and keeps pin/workspace metadata")
    func duplicateCleanup() throws {
        // Simulate a store that accumulated duplicates before canonicalization:
        // the same folder with and without a trailing slash.
        let ws = WorkspaceStore.create(named: "Kept", in: context)
        context.insert(ProjectRecord(name: "app", path: "/tmp/dup/app", dateAdded: .now.addingTimeInterval(-100)))
        context.insert(ProjectRecord(name: "app", path: "/tmp/dup/app/", dateAdded: .now, isPinned: true, workspaceID: ws.id))

        ProjectStore.cleanupDuplicates(in: context)

        let remaining = try context.fetch(FetchDescriptor<ProjectRecord>())
        #expect(remaining.count == 1)
        let kept = try #require(remaining.first)
        #expect(kept.isPinned)                    // merged from the newer duplicate
        #expect(kept.workspaceID == ws.id)        // merged from the newer duplicate
        #expect(!kept.path.hasSuffix("/"))        // stored path normalized
    }

    @Test("Settings row is created once and reused")
    func settingsSingleton() {
        let a = EnvHubStore.settings(in: context)
        a.maskByDefault = false
        let b = EnvHubStore.settings(in: context)
        #expect(a.persistentModelID == b.persistentModelID)
        #expect(b.maskByDefault == false)
    }

    @Test("Classification rules round-trip through encoded storage")
    func rulesRoundTrip() {
        let settings = EnvHubStore.settings(in: context)
        #expect(settings.classificationRules.map(\.kind) == [.example, .local, .production, .staging, .development])
        settings.classificationRules.append(ClassificationRule(pattern: "test", kind: .other))
        #expect(settings.classificationRules.count == 6)
        #expect(settings.classificationRules.last?.pattern == "test")
    }

    @Test("A stored legacy default ruleset is upgraded; a customized one is untouched")
    func legacyRuleMigration() {
        let settings = EnvHubStore.settings(in: context)

        // Simulate a store written before the Local/Example kinds existed.
        settings.classificationRules = ClassificationRule.legacyDefaults
        _ = EnvHubStore.settings(in: context)
        #expect(settings.classificationRules.map(\.kind) == ClassificationRule.defaults.map(\.kind))

        // Any user customization opts the ruleset out of migration.
        var custom = ClassificationRule.legacyDefaults
        custom[0].pattern = "my-prod"
        settings.classificationRules = custom
        _ = EnvHubStore.settings(in: context)
        #expect(settings.classificationRules.map(\.pattern) == ["my-prod", "stag|staging", "dev|development|^\\.env$"])
    }

    @Test("A stored legacy exclusion list is upgraded; a customized one is untouched")
    func legacyExclusionMigration() {
        let settings = EnvHubStore.settings(in: context)

        settings.exclusions = ScanConfig.legacyDefaultExclusions
        _ = EnvHubStore.settings(in: context)
        #expect(settings.exclusions == ScanConfig.defaultExclusions)
        #expect(settings.exclusions.contains("Library"))

        settings.exclusions = ["node_modules", "my-custom-dir"]
        _ = EnvHubStore.settings(in: context)
        #expect(settings.exclusions == ["node_modules", "my-custom-dir"])
    }
}
