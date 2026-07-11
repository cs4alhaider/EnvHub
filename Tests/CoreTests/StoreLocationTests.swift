import Foundation
import Testing
@testable import Core

@Suite("EnvHubStore location & migration")
struct StoreLocationTests {
    private let home = URL(fileURLWithPath: "/Users/demo")
    private let suffix = "Library/Application Support/EnvHub/EnvHub.store"

    @Test("ENVHUB_STORE override wins over everything")
    func overrideWins() {
        let url = EnvHubStore.resolveStoreURL(
            override: "/tmp/x/EnvHub.store",
            groupContainer: URL(fileURLWithPath: "/g"),
            home: home, isSandboxed: false, isUsable: { _ in true }
        )
        #expect(url.path == "/tmp/x/EnvHub.store")
    }

    @Test("Entitled builds use the group container")
    func groupContainer() {
        let url = EnvHubStore.resolveStoreURL(
            override: nil,
            groupContainer: URL(fileURLWithPath: "/Users/demo/Library/Group Containers/G.id"),
            home: home, isSandboxed: true, isUsable: { _ in true }
        )
        #expect(url.path == "/Users/demo/Library/Group Containers/G.id/\(suffix)")
    }

    @Test("Un-entitled + unsandboxed (CLI, dev builds) use the literal group path")
    func literalGroupPath() {
        let url = EnvHubStore.resolveStoreURL(
            override: nil, groupContainer: nil,
            home: home, isSandboxed: false, isUsable: { _ in true }
        )
        #expect(url.path == "/Users/demo/Library/Group Containers/\(EnvHubStore.appGroupID)/\(suffix)")
    }

    @Test("Sandboxed without the group entitlement falls back to Application Support")
    func sandboxedFallback() {
        let url = EnvHubStore.resolveStoreURL(
            override: nil, groupContainer: nil,
            home: home, isSandboxed: true, isUsable: { _ in true }
        )
        #expect(url == URL.applicationSupportDirectory.appending(path: "EnvHub/EnvHub.store"))
    }

    @Test("An unusable group directory falls back to Application Support")
    func unusableGroupFallsBack() {
        let url = EnvHubStore.resolveStoreURL(
            override: nil,
            groupContainer: URL(fileURLWithPath: "/g"),
            home: home, isSandboxed: false, isUsable: { _ in false }
        )
        #expect(url == URL.applicationSupportDirectory.appending(path: "EnvHub/EnvHub.store"))
    }

    @Test("File migration copies the store and its sidecars once, never overwrites")
    func fileMigration() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appending(path: "envhub-migrate-\(UUID().uuidString)")
        let source = base.appending(path: "old/EnvHub.store")
        let destination = base.appending(path: "new/EnvHub.store")
        try fm.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }

        try Data("db".utf8).write(to: source)
        try Data("wal".utf8).write(to: URL(fileURLWithPath: source.path + "-wal"))

        EnvHubStore.migrateFileStore(from: source, to: destination)
        #expect(try Data(contentsOf: destination) == Data("db".utf8))
        #expect(fm.fileExists(atPath: destination.path + "-wal"))
        #expect(!fm.fileExists(atPath: destination.path + "-shm"))   // absent sidecar skipped
        #expect(fm.fileExists(atPath: source.path))                  // source left in place

        // A second run must not clobber a live destination.
        try Data("newer".utf8).write(to: destination)
        EnvHubStore.migrateFileStore(from: source, to: destination)
        #expect(try Data(contentsOf: destination) == Data("newer".utf8))
    }

    @Test("Same source and destination is a no-op")
    func samePathNoOp() throws {
        let fm = FileManager.default
        let base = fm.temporaryDirectory.appending(path: "envhub-same-\(UUID().uuidString)")
        let store = base.appending(path: "EnvHub.store")
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: base) }
        try Data("db".utf8).write(to: store)
        EnvHubStore.migrateFileStore(from: store, to: store)
        #expect(try Data(contentsOf: store) == Data("db".utf8))
    }
}
