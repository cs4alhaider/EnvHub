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
        #expect(settings.classificationRules.map(\.kind) == [.production, .staging, .development])
        settings.classificationRules.append(ClassificationRule(pattern: "test", kind: .other))
        #expect(settings.classificationRules.count == 4)
        #expect(settings.classificationRules.last?.pattern == "test")
    }
}
