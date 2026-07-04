import Testing
import Foundation
@testable import Core

@Suite("Library export")
struct LibraryExportTests {
    private func makeProject(_ name: String, in dir: URL, files: [String: String]) throws -> Project {
        let folder = dir.appendingPathComponent(name + "-" + UUID().uuidString.prefix(6))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (fileName, content) in files {
            try content.write(to: folder.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
        }
        let envFiles = ProjectLoader.envFiles(in: folder, rules: ClassificationRule.defaults)
        return Project(name: name, path: folder, files: envFiles)
    }

    @Test("Round-trips every project into per-project subfolders, uniquifying name clashes")
    func libraryRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("envhub-library-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        // Two projects sharing a display name plus a distinct one.
        let a = try makeProject("web-app", in: dir, files: [".env": "# api\nA=1\n"])
        let b = try makeProject("web-app", in: dir, files: [".env": "B=2\n", ".env.production": "B=3\n"])
        let c = try makeProject("api", in: dir, files: [".env": "C=4\n"])

        let export = try EnvExporter.makeLibraryExport(name: "Everything", projects: [a, b, c])
        #expect(export.type == .library)
        #expect(Set(export.files.compactMap(\.project)) == ["web-app", "web-app-2", "api"])
        #expect(export.files.count == 4)

        // Materialize recreates one subfolder per project, contents byte-faithful.
        let out = dir.appendingPathComponent("restored")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let written = try EnvExporter.materialize(export, into: out)
        #expect(written.count == 4)
        #expect(try String(contentsOf: out.appendingPathComponent("web-app/.env"), encoding: .utf8) == "# api\nA=1\n")
        #expect(try String(contentsOf: out.appendingPathComponent("web-app-2/.env.production"), encoding: .utf8) == "B=3\n")
        #expect(FileManager.default.fileExists(atPath: out.appendingPathComponent("api/.env").path(percentEncoded: false)))
    }
}
