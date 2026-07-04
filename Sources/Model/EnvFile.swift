import Foundation

/// One `.env` file on disk: its absolute path and the environment it classifies into.
/// This is lightweight metadata — the parsed contents live in an `EnvDocument`, loaded
/// on demand when the file is opened for editing. Identity is the file path.
public struct EnvFile: Identifiable, Sendable, Hashable, Codable {
    public var path: URL
    public var kind: EnvKind

    public var id: URL { path }

    /// The file's last path component, e.g. `.env.production`.
    public var fileName: String { path.lastPathComponent }

    public init(path: URL, kind: EnvKind) {
        self.path = path
        self.kind = kind
    }
}
