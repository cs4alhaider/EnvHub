import Testing
import Foundation
@testable import Core

@Suite("ProjectSearch")
struct ProjectSearchTests {
    private let index = [
        IndexedVariable(projectID: UUID(), projectName: "web", projectPath: "/web",
                        fileURL: URL(filePath: "/web/.env.production"), fileName: ".env.production",
                        kind: .production, key: "GEMINI_API_KEY", value: "abc123"),
        IndexedVariable(projectID: UUID(), projectName: "api", projectPath: "/api",
                        fileURL: URL(filePath: "/api/.env"), fileName: ".env",
                        kind: .development, key: "DATABASE_URL", value: "postgres://localhost"),
    ]

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
}
