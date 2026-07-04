import Foundation
import Scanner
import Crypto

/// Stateless, `Sendable` services injected into SwiftUI via custom `EnvironmentKey`s
/// (defined in the `Helper` module). Keeping them value-type-stateless lets the
/// environment keys provide a `defaultValue` without main-actor gymnastics; any UI
/// progress state is owned by the views/view-models that call these methods.
///
/// Every method that does real work is `@concurrent async`: callers (usually the main
/// actor) just `await`, and the filesystem/CPU work is guaranteed to run off their
/// actor — no `Task.detached` needed at call sites.

/// Discovers `.env` files under chosen folders. The heavy lifting lives in the
/// `Scanner` target; this is the Core-facing entry point the app injects and calls.
public struct ScanService: Sendable {
    public init() {}

    /// Cancellable, off-main discovery. Cancel by cancelling the enclosing `Task`.
    /// Progress arrives on `onProgress`, throttled by the scanner (see `EnvScanner`).
    @concurrent
    public func scan(
        roots: [URL],
        config: ScanConfig,
        onProgress: (@Sendable (ScanProgress) -> Void)? = nil
    ) async -> [DiscoveredProject] {
        await EnvScanner.scan(roots: roots, config: config, onProgress: onProgress)
    }
}

/// Encrypted `.envenc` export/import (AES-256-GCM + scrypt). Wraps `EnvCrypto` and
/// `EnvExporter` so the app and CLI call one entry point. scrypt is deliberately
/// expensive (~hundreds of ms), which is exactly why these are `@concurrent`.
public struct CryptoService: Sendable {
    public init() {}

    /// Encrypt a single env file into `.envenc` data.
    @concurrent
    public func exportSingle(fileURL: URL, kind: EnvKind?, password: String, params: ScryptParams = .default) async throws -> Data {
        try EnvCrypto.encrypt(EnvExporter.makeExport(fileURL: fileURL, kind: kind), password: password, params: params)
    }

    /// Encrypt a whole project's env files into `.envenc` data.
    @concurrent
    public func exportProject(name: String, files: [EnvFile], password: String, params: ScryptParams = .default) async throws -> Data {
        try EnvCrypto.encrypt(EnvExporter.makeExport(projectName: name, files: files), password: password, params: params)
    }

    /// Decrypt `.envenc` data. Throws `EnvelopeError.wrongPasswordOrCorrupted` when the
    /// password is wrong (GCM authentication), `.malformedEnvelope` for non-envenc data.
    @concurrent
    public func decrypt(_ data: Data, password: String) async throws -> EnvExport {
        try EnvCrypto.decrypt(data, password: password)
    }

    /// Convenience: read a `.envenc` file and decrypt it, all off the caller's actor.
    @concurrent
    public func decrypt(contentsOf url: URL, password: String) async throws -> EnvExport {
        try EnvCrypto.decrypt(Data(contentsOf: url), password: password)
    }

    /// Write a decrypted export's files into `folder`; returns the URLs written.
    @concurrent
    @discardableResult
    public func materialize(_ export: EnvExport, into folder: URL, overwrite: Bool) async throws -> [URL] {
        try EnvExporter.materialize(export, into: folder, overwrite: overwrite)
    }
}
