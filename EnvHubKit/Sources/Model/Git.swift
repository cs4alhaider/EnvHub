import Foundation

/// Git status of a single env file within a project.
public struct GitFileStatus: Sendable, Hashable {
    public var url: URL
    /// Tracked by git (in the index / committed) — a leak risk for secrets.
    public var isTracked: Bool
    /// Matched by a `.gitignore` rule.
    public var isIgnored: Bool

    public init(url: URL, isTracked: Bool, isIgnored: Bool) {
        self.url = url
        self.isTracked = isTracked
        self.isIgnored = isIgnored
    }
}

/// Git status for a project's env files.
public struct GitInfo: Sendable, Hashable {
    public var isRepo: Bool
    public var repoRoot: URL?
    public var statuses: [GitFileStatus]

    public init(isRepo: Bool, repoRoot: URL?, statuses: [GitFileStatus]) {
        self.isRepo = isRepo
        self.repoRoot = repoRoot
        self.statuses = statuses
    }

    public func status(for url: URL) -> GitFileStatus? { statuses.first { $0.url == url } }
    public var trackedFiles: [URL] { statuses.filter(\.isTracked).map(\.url) }
}
