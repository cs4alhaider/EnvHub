import Foundation

/// A non-blocking warning about a line in a `.env` file — surfaced inline in the editor
/// as a small marker. Derived from an `EnvDocument`; never stored on `EnvVar`.
public struct EnvDiagnostic: Sendable, Hashable, Codable, Identifiable {
    public enum Kind: String, Sendable, Hashable, Codable {
        case duplicateKey
        case missingEquals
        case emptyKey
        case unbalancedQuotes
    }

    public var id: UUID
    /// 1-based line number in the source file, when known.
    public var lineNumber: Int?
    /// The offending key, when applicable.
    public var key: String?
    public var kind: Kind
    public var message: String

    public init(id: UUID = UUID(), lineNumber: Int?, key: String?, kind: Kind, message: String) {
        self.id = id
        self.lineNumber = lineNumber
        self.key = key
        self.kind = kind
        self.message = message
    }
}
