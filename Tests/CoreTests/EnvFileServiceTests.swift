import Testing
import Foundation
@testable import Core

@Suite("EnvFileService save/backup")
struct EnvFileServiceTests {
    private func tempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("envhub-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("Save writes a .bak of the old file, then new content, preserving comments")
    func saveWithBackup() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent(".env")
        let original = "# comment\nA=1\nB=2\n"
        try original.write(to: file, atomically: true, encoding: .utf8)

        let doc = try EnvFileService.load(file)
        var vars = doc.variables
        vars[vars.firstIndex { $0.key == "B" }!].value = "22"
        try EnvFileService.save(original: doc, variables: vars, to: file)

        // New content: only B changed; comment + A preserved.
        #expect(try String(contentsOf: file, encoding: .utf8) == "# comment\nA=1\nB=22\n")

        // Backup holds the pre-save content.
        let backup = EnvFileService.backupURL(for: file)
        #expect(FileManager.default.fileExists(atPath: backup.path(percentEncoded: false)))
        #expect(try String(contentsOf: backup, encoding: .utf8) == original)
    }

    @Test("Backup URL appends .bak to the whole filename")
    func backupNaming() {
        #expect(EnvFileService.backupURL(for: URL(filePath: "/x/.env")).lastPathComponent == ".env.bak")
        #expect(EnvFileService.backupURL(for: URL(filePath: "/x/.env.production")).lastPathComponent == ".env.production.bak")
    }

    @Test("No backup is created when the file did not previously exist")
    func saveNoPriorFile() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent(".env")
        try "".write(to: file, atomically: true, encoding: .utf8)
        let emptyDoc = try EnvFileService.load(file)
        try FileManager.default.removeItem(at: file)     // simulate first-ever write

        try EnvFileService.save(original: emptyDoc, variables: [EnvVar(key: "A", value: "1")], to: file)

        #expect(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)))
        #expect(!FileManager.default.fileExists(atPath: EnvFileService.backupURL(for: file).path(percentEncoded: false)))
        #expect(try String(contentsOf: file, encoding: .utf8) == "A=1")
    }
}
