import Foundation
import Scanner
import Crypto

/// Stateless, `Sendable` services injected into SwiftUI via custom `EnvironmentKey`s
/// (defined in the `Helper` module). Keeping them value-type-stateless lets the
/// environment keys provide a `defaultValue` without main-actor gymnastics; any UI
/// progress state is owned by the views/view-models that call these methods.

/// Discovers `.env` files under chosen folders. The heavy lifting lives in the
/// `Scanner` target; this is the Core-facing entry point the app injects and calls.
public struct ScanService: Sendable {
    public init() {}

    /// Cancellable, off-main discovery. Cancel by cancelling the enclosing `Task`.
    public func scan(
        roots: [URL],
        config: ScanConfig,
        onProgress: (@Sendable (ScanProgress) -> Void)? = nil
    ) async -> [DiscoveredProject] {
        await EnvScanner.scan(roots: roots, config: config, onProgress: onProgress)
    }
}

/// Encrypted `.envenc` export/import (AES-256-GCM + scrypt). Wraps `EnvCrypto` and
/// `EnvExporter` so the app and CLI call one entry point.
public struct CryptoService: Sendable {
    public init() {}

    public func exportSingle(fileURL: URL, kind: EnvKind?, password: String, params: ScryptParams = .default) throws -> Data {
        try EnvCrypto.encrypt(EnvExporter.makeExport(fileURL: fileURL, kind: kind), password: password, params: params)
    }

    public func exportProject(name: String, files: [EnvFile], password: String, params: ScryptParams = .default) throws -> Data {
        try EnvCrypto.encrypt(EnvExporter.makeExport(projectName: name, files: files), password: password, params: params)
    }

    public func decrypt(_ data: Data, password: String) throws -> EnvExport {
        try EnvCrypto.decrypt(data, password: password)
    }

    @discardableResult
    public func materialize(_ export: EnvExport, into folder: URL, overwrite: Bool) throws -> [URL] {
        try EnvExporter.materialize(export, into: folder, overwrite: overwrite)
    }
}
