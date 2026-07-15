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

    @Test("Search is exclusion-based: everything searchable by default, toggles persist")
    func searchKinds() {
        let settings = EnvHubStore.settings(in: context)
        // Default: nothing excluded, so every catalog kind (and unknown kinds) search.
        #expect(settings.searchExcludedKinds.isEmpty)
        #expect(settings.isSearchable(.example))
        #expect(settings.isSearchable(EnvKind(rawValue: "uat")))   // unknown kind defaults visible

        settings.setSearchable(.example, false)
        #expect(settings.searchExcludedKinds == [EnvKind.example.rawValue])
        #expect(!settings.isSearchable(.example))
        #expect(settings.isSearchable(.development))

        settings.setSearchable(.example, true)
        #expect(settings.searchExcludedKinds.isEmpty)
    }

    @Test("Environment definitions default to the shipped catalog and round-trip")
    func environmentDefinitions() {
        let settings = EnvHubStore.settings(in: context)
        #expect(settings.environmentDefinitions == EnvironmentDefinition.defaults)

        let uat = EnvKind.slug(from: "UAT")
        var defs = settings.environmentDefinitions
        defs.insert(EnvironmentDefinition(kind: uat, title: "UAT", color: .teal), at: 2)
        settings.environmentDefinitions = defs
        #expect(settings.environmentCatalog.title(for: uat) == "UAT")
        #expect(settings.environmentCatalog.color(for: uat) == .teal)
    }

    @Test("removeAll forgets projects but keeps workspaces and settings; reset wipes everything")
    func removeAllAndReset() throws {
        let ws = WorkspaceStore.create(named: "Keep", in: context)
        _ = ProjectStore.addProject(at: URL(filePath: "/tmp/one"), to: context, workspaceID: ws.id)
        _ = ProjectStore.addProject(at: URL(filePath: "/tmp/two"), to: context)
        context.insert(ScanFolderRecord(path: "/tmp"))
        EnvHubStore.settings(in: context).maskByDefault = false

        ProjectStore.removeAll(in: context)
        #expect(try context.fetch(FetchDescriptor<ProjectRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WorkspaceRecord>()).count == 1)
        #expect(EnvHubStore.settings(in: context).maskByDefault == false)

        EnvHubStore.reset(in: context)
        #expect(try context.fetch(FetchDescriptor<WorkspaceRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ScanFolderRecord>()).isEmpty)
        // A fresh settings row comes back with defaults (mask on, onboarding unseen).
        let fresh = EnvHubStore.settings(in: context)
        #expect(fresh.maskByDefault == true)
        #expect(fresh.hasSeenOnboarding == false)
    }
}
