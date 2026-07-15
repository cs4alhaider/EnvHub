import Testing
import Foundation
@testable import Scanner
import Model

@Suite("EnvScanner")
struct ScannerTests {
    private func makeTree() throws -> URL {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("envhub-scan-\(UUID().uuidString)")
        func mk(_ p: String) throws {
            try fm.createDirectory(at: root.appendingPathComponent(p), withIntermediateDirectories: true)
        }
        func write(_ p: String) throws {
            try "X=1".write(to: root.appendingPathComponent(p), atomically: true, encoding: .utf8)
        }
        try mk("serviceA/node_modules")
        try mk("serviceB/nested")
        try mk(".git")
        try write(".env")
        try write("serviceA/.env")
        try write("serviceA/.env.production")
        try write("serviceA/.env.bak")            // backup — ignored
        try write("serviceA/node_modules/.env")   // excluded dir
        try write("serviceB/nested/.env")
        try write(".git/.env")                     // excluded dir
        return root
    }

    @Test("Deep scan groups by folder, honors exclusions, ignores .bak")
    func deepScan() async throws {
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }
        var config = ScanConfig.default
        config.deepScan = true

        let projects = await EnvScanner.scan(roots: [root], config: config)
        let byName = Dictionary(grouping: projects, by: { $0.folder.lastPathComponent })

        #expect(byName[root.lastPathComponent]?.first?.files.count == 1)   // root/.env
        #expect(byName["serviceA"]?.first?.files.count == 2)               // .env + .env.production
        #expect(byName["nested"]?.first?.files.count == 1)                 // serviceB/nested/.env
        // Nothing from excluded directories:
        #expect(projects.allSatisfy {
            !$0.folder.path.contains("node_modules") && !$0.folder.path.contains(".git")
        })
    }

    @Test("Shallow scan only finds env files directly in the roots")
    func shallowScan() async throws {
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }
        var config = ScanConfig.default
        config.deepScan = false

        let projects = await EnvScanner.scan(roots: [root], config: config)
        #expect(projects.count == 1)
        #expect(projects.first?.files.count == 1)
    }

    @Test("Cancellation returns promptly without hanging or crashing")
    func cancellation() async throws {
        let root = try makeTree()
        defer { try? FileManager.default.removeItem(at: root) }
        var config = ScanConfig.default
        config.deepScan = true

        let task = Task { await EnvScanner.scan(roots: [root], config: config) }
        task.cancel()
        let result = await task.value
        #expect(result.count >= 0)
    }

    @Test("Matcher globs default patterns and skips backups")
    func matcher() {
        let patterns = ScanConfig.defaultFilenamePatterns
        #expect(EnvFileMatcher.matches(fileName: ".env", patterns: patterns))
        #expect(EnvFileMatcher.matches(fileName: ".env.production", patterns: patterns))
        #expect(!EnvFileMatcher.matches(fileName: ".env.bak", patterns: patterns))
        #expect(!EnvFileMatcher.matches(fileName: "config.yml", patterns: patterns))
    }
}
