import Testing
import Foundation
import SwiftData
@testable import Core

@MainActor
@Suite("WorkspaceStore")
struct WorkspaceStoreTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try EnvHubStore.container(inMemory: true)
    }

    private func addProject(_ name: String, path: String? = nil) -> ProjectRecord {
        ProjectStore.addProject(at: URL(filePath: path ?? "/tmp/\(name)"), to: context)!
    }

    @Test("Create appends in order and dedupes by case-insensitive name")
    func createDedupes() {
        let a = WorkspaceStore.create(named: "Backend", in: context)
        let b = WorkspaceStore.create(named: "Frontend", in: context)
        #expect(WorkspaceStore.all(in: context).map(\.name) == ["Backend", "Frontend"])
        #expect(b.sortOrder > a.sortOrder)

        let dupe = WorkspaceStore.create(named: "  backend ", in: context)
        #expect(dupe.id == a.id)
        #expect(WorkspaceStore.all(in: context).count == 2)
    }

    @Test("Assign moves a project between sections; members reflects it")
    func assignAndMembers() {
        let ws = WorkspaceStore.create(named: "Apps", in: context)
        let p1 = addProject("alpha")
        let p2 = addProject("beta")

        WorkspaceStore.assign(p1, to: ws)
        #expect(WorkspaceStore.members(of: ws, in: [p1, p2]).map(\.name) == ["alpha"])
        #expect(WorkspaceStore.members(of: nil, in: [p1, p2]).map(\.name) == ["beta"])

        WorkspaceStore.assign(p1, to: nil)   // back to Others
        #expect(WorkspaceStore.members(of: ws, in: [p1, p2]).isEmpty)
    }

    @Test("Deleting a workspace ungroups its projects instead of deleting them")
    func deleteUngroups() throws {
        let ws = WorkspaceStore.create(named: "Doomed", in: context)
        let p = addProject("survivor")
        WorkspaceStore.assign(p, to: ws)

        WorkspaceStore.delete(ws, in: context)
        #expect(WorkspaceStore.all(in: context).isEmpty)
        #expect(p.workspaceID == nil)
        #expect(try context.fetch(FetchDescriptor<ProjectRecord>()).count == 1)
    }

    @Test("sortProjects writes a manual order that ordered() respects")
    func sortWritesOrder() {
        let ws = WorkspaceStore.create(named: "Sorted", in: context)
        let a = addProject("zebra", path: "/tmp/1/zebra")
        let b = addProject("apple", path: "/tmp/2/apple")
        let c = addProject("mango", path: "/tmp/3/mango")
        for p in [a, b, c] { WorkspaceStore.assign(p, to: ws) }

        WorkspaceStore.sortProjects(in: ws, by: .name, context: context)
        #expect(WorkspaceStore.members(of: ws, in: [a, b, c]).map(\.name) == ["apple", "mango", "zebra"])

        WorkspaceStore.sortProjects(in: ws, by: .path, context: context)
        #expect(WorkspaceStore.members(of: ws, in: [a, b, c]).map(\.name) == ["zebra", "apple", "mango"])
    }

    @Test("Legacy store import copies projects, workspaces, folders, and settings once")
    func legacyImport() throws {
        // Build a "legacy" store in a temp file with a few records.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("envhub-legacy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let legacyURL = dir.appendingPathComponent("default.store")

        let legacy = try ModelContainer(
            for: EnvHubStore.schema,
            configurations: [ModelConfiguration(schema: EnvHubStore.schema, url: legacyURL)]
        )
        let legacyContext = ModelContext(legacy)
        legacyContext.insert(ProjectRecord(name: "old-app", path: "/tmp/old-app", isPinned: true))
        legacyContext.insert(ScanFolderRecord(path: "/tmp/scan-root"))
        legacyContext.insert(AppSettings(maskByDefault: false))
        try legacyContext.save()

        // Import into a fresh (in-memory) container and verify everything arrived.
        let fresh = try EnvHubStore.container(inMemory: true)
        try EnvHubStore.importLegacyStore(from: legacyURL, into: fresh)

        let projects = try ModelContext(fresh).fetch(FetchDescriptor<ProjectRecord>())
        #expect(projects.map(\.name) == ["old-app"])
        #expect(projects.first?.isPinned == true)
        #expect(try ModelContext(fresh).fetch(FetchDescriptor<ScanFolderRecord>()).count == 1)
        #expect(try ModelContext(fresh).fetch(FetchDescriptor<AppSettings>()).first?.maskByDefault == false)
    }
}
