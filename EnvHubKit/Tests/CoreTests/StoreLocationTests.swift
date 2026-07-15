import Foundation
import Testing
@testable import Core

@Suite("EnvHubStore location")
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
}
