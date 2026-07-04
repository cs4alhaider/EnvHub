import Testing
import Foundation
@testable import Core

@Suite("GitService")
struct GitServiceTests {
    private func tempRepo() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("envhub-git-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        _ = GitService.git(["init"], in: dir)
        return dir
    }

    @Test("Detects a repo vs. a non-repo folder")
    func repoDetection() async throws {
        let repo = try tempRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        #expect(await GitService.repoRoot(for: repo) != nil)

        let plain = FileManager.default.temporaryDirectory.appendingPathComponent("envhub-plain-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: plain) }
        #expect(await GitService.repoRoot(for: plain) == nil)
    }

    @Test("Tracks, then unstage-and-ignore untracks + gitignores")
    func trackThenIgnore() async throws {
        let repo = try tempRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let env = repo.appendingPathComponent(".env")
        try "A=1".write(to: env, atomically: true, encoding: .utf8)

        #expect(await GitService.isTracked(env, in: repo) == false)
        _ = GitService.git(["add", ".env"], in: repo)
        #expect(await GitService.isTracked(env, in: repo) == true)

        try await GitService.unstageAndIgnore(env, in: repo)
        #expect(await GitService.isTracked(env, in: repo) == false)
        #expect(await GitService.isInGitignore(".env", folder: repo) == true)
        #expect(await GitService.isIgnored(env, in: repo) == true)

        try await GitService.removeFromGitignore(".env", folder: repo)
        #expect(await GitService.isInGitignore(".env", folder: repo) == false)
    }

    @Test("info summarizes tracked and ignored env files with batched git calls")
    func infoSummary() async throws {
        let repo = try tempRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let env = repo.appendingPathComponent(".env")
        let local = repo.appendingPathComponent(".env.local")
        try "A=1".write(to: env, atomically: true, encoding: .utf8)
        try "B=2".write(to: local, atomically: true, encoding: .utf8)
        _ = GitService.git(["add", ".env"], in: repo)
        try await GitService.addToGitignore(".env.local", folder: repo)

        let info = await GitService.info(folder: repo, files: [env, local])
        #expect(info.isRepo)
        #expect(info.trackedFiles == [env])
        #expect(info.status(for: local)?.isIgnored == true)
        #expect(info.status(for: env)?.isIgnored == false)
    }

    @Test("info on a non-repo folder reports isRepo == false")
    func infoNonRepo() async throws {
        let plain = FileManager.default.temporaryDirectory.appendingPathComponent("envhub-plain-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: plain) }
        let info = await GitService.info(folder: plain, files: [plain.appendingPathComponent(".env")])
        #expect(!info.isRepo)
        #expect(info.statuses.isEmpty)
    }

    @Test("Create makes a blank file and copies keys with cleared values")
    func createFile() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("envhub-create-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let source = dir.appendingPathComponent(".env")
        try "API_KEY=secret\nPORT=3000\n".write(to: source, atomically: true, encoding: .utf8)

        let example = dir.appendingPathComponent(".env.example")
        try EnvFileService.create(at: example, copyingKeysFrom: source)
        #expect(try String(contentsOf: example, encoding: .utf8) == "API_KEY=\nPORT=\n")

        // Refuses to overwrite.
        #expect(throws: EnvExportError.fileExists(example)) {
            try EnvFileService.create(at: example, copyingKeysFrom: nil)
        }
    }
}

@Suite("ProjectMetadata")
struct ProjectMetadataTests {
    @Test("Loads variable counts, git status, and gitignore membership in one shot")
    func loadAll() async throws {
        let repo = FileManager.default.temporaryDirectory.appendingPathComponent("envhub-meta-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: repo) }
        _ = GitService.git(["init"], in: repo)

        let env = repo.appendingPathComponent(".env")
        let prod = repo.appendingPathComponent(".env.production")
        try "A=1\nB=2\n".write(to: env, atomically: true, encoding: .utf8)
        try "C=3\n".write(to: prod, atomically: true, encoding: .utf8)
        _ = GitService.git(["add", ".env"], in: repo)
        try await GitService.addToGitignore(".env.production", folder: repo)

        let metadata = await ProjectMetadata.load(folder: repo, files: [env, prod])
        #expect(metadata.variableCounts[env] == 2)
        #expect(metadata.variableCounts[prod] == 1)
        #expect(metadata.gitInfo.isRepo)
        #expect(metadata.gitInfo.trackedFiles == [env])
        #expect(metadata.gitignoredFileNames == [".env.production"])
    }
}
