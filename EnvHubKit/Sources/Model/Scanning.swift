import Foundation

/// Progress emitted during a filesystem scan, for driving UI (counts + current path).
public struct ScanProgress: Sendable, Hashable {
    public var directoriesVisited: Int
    public var filesFound: Int
    public var currentPath: String?

    public init(directoriesVisited: Int = 0, filesFound: Int = 0, currentPath: String? = nil) {
        self.directoriesVisited = directoriesVisited
        self.filesFound = filesFound
        self.currentPath = currentPath
    }
}

/// A folder discovered by the scanner that contains at least one env file — becomes a
/// Project when the user accepts it.
public struct DiscoveredProject: Sendable, Hashable, Identifiable {
    public var folder: URL
    public var files: [URL]

    public var id: URL { folder }
    public var name: String { folder.lastPathComponent }

    public init(folder: URL, files: [URL]) {
        self.folder = folder
        self.files = files
    }
}
