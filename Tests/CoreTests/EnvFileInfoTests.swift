import Foundation
import Testing
@testable import Core

@Suite("EnvFileInfo")
struct EnvFileInfoTests {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "envhub-fileinfo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @Test("Reads dates, size, and writability for an existing file")
    func basicAttributes() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appending(path: ".env")
        try Data("API_KEY=x\n".utf8).write(to: file)

        let info = await EnvFileInfo.load(for: file)
        #expect(info.sizeBytes == 10)
        #expect(info.isWritable)
        #expect(info.createdAt != nil)
        #expect(info.modifiedAt != nil)
        #expect(info.backupFileName == nil)
        #expect(info.backupModifiedAt == nil)
    }

    @Test("Detects the .bak sibling written by backup-on-save")
    func backupDetection() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appending(path: ".env.production")
        try Data("A=1\n".utf8).write(to: file)
        let backup = EnvFileService.backupURL(for: file)
        try Data("A=0\n".utf8).write(to: backup)

        let info = await EnvFileInfo.load(for: file)
        #expect(info.backupFileName == ".env.production.bak")
        #expect(info.backupModifiedAt != nil)
    }

    @Test("A missing file yields empty attributes (and is not writable)")
    func missingFile() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let info = await EnvFileInfo.load(for: dir.appending(path: "gone.env"))
        #expect(info.createdAt == nil)
        #expect(info.modifiedAt == nil)
        #expect(info.sizeBytes == nil)
        #expect(!info.isWritable)
    }
}
