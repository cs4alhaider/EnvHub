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
    func repoDetection() throws {
        let repo = try tempRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        #expect(GitService.repoRoot(for: repo) != nil)

        let plain = FileManager.default.temporaryDirectory.appendingPathComponent("envhub-plain-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: plain) }
        #expect(GitService.repoRoot(for: plain) == nil)
    }

    @Test("Tracks, then unstage-and-ignore untracks + gitignores")
    func trackThenIgnore() throws {
        let repo = try tempRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let env = repo.appendingPathComponent(".env")
        try "A=1".write(to: env, atomically: true, encoding: .utf8)

        #expect(GitService.isTracked(env, in: repo) == false)
        _ = GitService.git(["add", ".env"], in: repo)
        #expect(GitService.isTracked(env, in: repo) == true)

        try GitService.unstageAndIgnore(env, in: repo)
        #expect(GitService.isTracked(env, in: repo) == false)
        #expect(GitService.isInGitignore(".env", folder: repo) == true)
        #expect(GitService.isIgnored(env, in: repo) == true)

        try GitService.removeFromGitignore(".env", folder: repo)
        #expect(GitService.isInGitignore(".env", folder: repo) == false)
    }

    @Test("info summarizes tracked env files")
    func infoSummary() throws {
        let repo = try tempRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        let env = repo.appendingPathComponent(".env")
        try "A=1".write(to: env, atomically: true, encoding: .utf8)
        _ = GitService.git(["add", ".env"], in: repo)

        let info = GitService.info(folder: repo, files: [env])
        #expect(info.isRepo)
        #expect(info.trackedFiles == [env])
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
