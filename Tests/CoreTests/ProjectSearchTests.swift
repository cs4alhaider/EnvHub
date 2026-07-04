import Testing
import Foundation
@testable import Core

@Suite("ProjectSearch")
struct ProjectSearchTests {
    private let webID = UUID()
    private let apiID = UUID()

    private var index: SearchIndex {
        SearchIndex(variables: [
            IndexedVariable(projectID: webID, projectName: "web", projectPath: "/web",
                            fileURL: URL(filePath: "/web/.env.production"), fileName: ".env.production",
                            kind: .production, key: "GEMINI_API_KEY", value: "abc123"),
            IndexedVariable(projectID: apiID, projectName: "api", projectPath: "/api",
                            fileURL: URL(filePath: "/api/.env"), fileName: ".env",
                            kind: .development, key: "DATABASE_URL", value: "postgres://localhost"),
        ])
    }

    @Test("Finds a key by case-insensitive substring")
    func findsKey() {
        let hits = ProjectSearch.search("gemini", in: index)
        #expect(hits.count == 1)
        #expect(hits.first?.key == "GEMINI_API_KEY")
        #expect(hits.first?.projectName == "web")
    }

    @Test("Matches values, filenames, and project names too")
    func matchesOtherFields() {
        #expect(ProjectSearch.search("postgres", in: index).count == 1)   // value
        #expect(ProjectSearch.search("production", in: index).count == 1) // filename
        #expect(ProjectSearch.search("web", in: index).count == 1)        // project name
    }

    @Test("Substring matches span keys and names (e.g. “api” hits GEMINI_API_KEY and the api project)")
    func substringSpansFields() {
        #expect(ProjectSearch.search("api", in: index).count == 2)
    }

    @Test("Blank query matches nothing")
    func blankQuery() {
        #expect(ProjectSearch.search("   ", in: index).isEmpty)
    }

    @Test("projectMatches hits name and path, case-insensitively")
    func projectPredicate() {
        #expect(ProjectSearch.projectMatches(query: "WEB", name: "web", path: "/web"))
        #expect(ProjectSearch.projectMatches(query: "api", name: "backend", path: "/srv/api"))
        #expect(!ProjectSearch.projectMatches(query: "mobile", name: "web", path: "/web"))
        #expect(!ProjectSearch.projectMatches(query: "  ", name: "web", path: "/web"))
    }

    @Test("Grouping keeps one section per project, sorted by name, hits in order")
    func grouping() {
        let hits = ProjectSearch.search("_", in: index)   // matches both keys
        let groups = ProjectSearch.groupedByProject(hits)
        #expect(groups.map(\.name) == ["api", "web"])     // name-sorted
        #expect(groups.first?.hits.first?.key == "DATABASE_URL")
        #expect(groups.first?.id == apiID)
    }
}

@Suite("SearchIndex")
struct SearchIndexTests {
    @Test("Builds from disk: indexes variables and counts files (including empty ones)")
    func buildFromDisk() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("envhub-index-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try "API_KEY=secret\nPORT=3000\n".write(
            to: dir.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
        try "".write(   // an empty env file still counts as a file
            to: dir.appendingPathComponent(".env.production"), atomically: true, encoding: .utf8)

        let project = Project(name: "demo", path: dir)
        let index = await SearchIndex.build(
            projects: [project],
            rules: ClassificationRule.defaults,
            patterns: ScanConfig.defaultFilenamePatterns
        )

        #expect(index.variables.count == 2)
        #expect(index.fileCounts[project.id] == 2)
        #expect(ProjectSearch.search("api_key", in: index).count == 1)
        #expect(index.variables.allSatisfy { $0.projectName == "demo" })
    }
}
