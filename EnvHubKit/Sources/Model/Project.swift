import Foundation

/// A folder containing one or more `.env` files. Discovered by the scanner (grouped by
/// parent folder) or added manually. Removing a project only forgets it in the app —
/// it never touches files on disk.
public struct Project: Identifiable, Sendable, Hashable, Codable {
    public var id: UUID
    /// Display name — defaults to the folder name.
    public var name: String
    /// Absolute path of the folder.
    public var path: URL
    /// The `.env` files found directly in this folder.
    public var files: [EnvFile]

    public init(id: UUID = UUID(), name: String, path: URL, files: [EnvFile] = []) {
        self.id = id
        self.name = name
        self.path = path
        self.files = files
    }

    /// Convenience: create a project named after its folder.
    public init(id: UUID = UUID(), path: URL, files: [EnvFile] = []) {
        self.init(id: id, name: path.lastPathComponent, path: path, files: files)
    }

    /// The distinct environments present, in display order (per the given catalog;
    /// the built-in one by default).
    public func environments(using catalog: EnvironmentCatalog = .builtin) -> [EnvKind] {
        catalog.sorted(Set(files.map(\.kind)))
    }

    /// Files belonging to a given environment, sorted by filename.
    public func files(in kind: EnvKind) -> [EnvFile] {
        files.filter { $0.kind == kind }.sorted { $0.fileName < $1.fileName }
    }
}
