import Testing
@testable import Model

@Suite("PathDisplay")
struct PathDisplayTests {
    @Test("Strips the home prefix")
    func underHome() {
        #expect(PathDisplay.homeRelative("/Users/me/Documents/GitHub/app", home: "/Users/me") == "Documents/GitHub/app")
    }

    @Test("Home itself becomes ~")
    func homeItself() {
        #expect(PathDisplay.homeRelative("/Users/me", home: "/Users/me") == "~")
    }

    @Test("Paths outside home are unchanged")
    func outsideHome() {
        #expect(PathDisplay.homeRelative("/opt/services/api", home: "/Users/me") == "/opt/services/api")
    }

    @Test("Sibling user folders are not treated as home")
    func siblingPrefix() {
        #expect(PathDisplay.homeRelative("/Users/melissa/app", home: "/Users/me") == "/Users/melissa/app")
    }

    @Test("Trailing slash on home is tolerated")
    func trailingSlash() {
        #expect(PathDisplay.homeRelative("/Users/me/app", home: "/Users/me/") == "app")
    }

    @Test("Degenerate home leaves paths unchanged")
    func degenerateHome() {
        #expect(PathDisplay.homeRelative("/anything/at/all", home: "/") == "/anything/at/all")
        #expect(PathDisplay.homeRelative("/anything/at/all", home: "") == "/anything/at/all")
    }
}
