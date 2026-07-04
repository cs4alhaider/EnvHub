import Foundation

/// Errors surfaced by the `.envenc` envelope (defined here in `Model` so the app — which
/// links `Core`, not the internal `Crypto` target — can present them).
public enum EnvelopeError: Error, Equatable {
    case unsupportedVersion(Int)
    case unsupportedKDF(String)
    case malformedEnvelope
    case invalidScryptParams
    /// GCM authentication failed — wrong password or tampered ciphertext.
    case wrongPasswordOrCorrupted
}

/// User-facing messages so `error.localizedDescription` reads well in both the app
/// and the CLI without either duplicating the mapping.
extension EnvelopeError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let v): "Unsupported .envenc version (\(v))."
        case .unsupportedKDF(let k): "Unsupported key-derivation function (\(k))."
        case .malformedEnvelope: "This isn’t a valid .envenc file."
        case .invalidScryptParams: "The file has invalid encryption parameters."
        case .wrongPasswordOrCorrupted: "Wrong password, or the file has been tampered with."
        }
    }
}

/// scrypt key-derivation parameters, serialized into the `.envenc` envelope.
public struct ScryptParams: Codable, Sendable, Hashable {
    public var N: Int
    public var r: Int
    public var p: Int

    public init(N: Int = 32768, r: Int = 8, p: Int = 1) {
        self.N = N
        self.r = r
        self.p = p
    }

    public static let `default` = ScryptParams()
}

/// One key/value pair in an export payload.
public struct EnvVarPayload: Codable, Sendable, Hashable {
    public var key: String
    public var value: String
    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// One file in an export payload: its key/value pairs plus the raw text (so import can
/// materialize it faithfully, comments and all).
public struct EnvFilePayload: Codable, Sendable, Hashable {
    public var name: String
    public var kind: String?
    public var variables: [EnvVarPayload]
    public var content: String?
    /// For `library` exports: the (uniquified) project folder name this file belongs
    /// to — import materializes it into a subfolder of that name. `nil` for single-
    /// file and single-project exports.
    public var project: String?

    public init(
        name: String,
        kind: String? = nil,
        variables: [EnvVarPayload],
        content: String? = nil,
        project: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.variables = variables
        self.content = content
        self.project = project
    }
}

/// The decrypted plaintext payload of a `.envenc` file: one env file (`single`), a
/// whole project's files (`project`), or every project's files (`library`).
public struct EnvExport: Codable, Sendable, Hashable {
    public enum Kind: String, Codable, Sendable {
        case single
        case project
        /// All projects at once (Settings → Data → Export All Variables). Each file
        /// carries its `project` name; import recreates one subfolder per project.
        case library
    }

    public var type: Kind
    public var name: String
    public var files: [EnvFilePayload]

    public init(type: Kind, name: String, files: [EnvFilePayload]) {
        self.type = type
        self.name = name
        self.files = files
    }
}
