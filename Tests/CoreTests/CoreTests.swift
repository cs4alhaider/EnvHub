import Testing
@testable import Core

@Suite("Core facade")
struct CoreTests {
    @Test("Core exposes a semantic version")
    func version() {
        #expect(Core.version == "0.0.1")
    }

    @Test("Core ties together all five concern modules")
    func modulesWired() {
        #expect(Core.modules == ["Model", "Parser", "Scanner", "Classifier", "Crypto"])
    }

    @Test("Model types are reachable through Core's re-export")
    func modelReexported() {
        // Visible only because Core does `@_exported import Model`.
        #expect(EnvKind.production.rawValue == "production")
        #expect(EnvVar(key: "K", value: "V").key == "K")
    }
}
