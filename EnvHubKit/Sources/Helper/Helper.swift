import SwiftUI
import Core

// `Helper` is the SwiftUI dependency-injection layer: custom `EnvironmentKey`s and
// `@Environment(\.…)` accessors that vend `Core`'s stateless services into views. The
// app injects them once at its root; views read them via `@Environment`. This is the
// only package target that imports SwiftUI, keeping the CLI free of any UI framework.

private struct ScanServiceKey: EnvironmentKey {
    static let defaultValue = ScanService()
}

private struct CryptoServiceKey: EnvironmentKey {
    static let defaultValue = CryptoService()
}

public extension EnvironmentValues {
    /// The shared `.env` discovery service.
    var scanService: ScanService {
        get { self[ScanServiceKey.self] }
        set { self[ScanServiceKey.self] = newValue }
    }

    /// The shared `.envenc` crypto service.
    var cryptoService: CryptoService {
        get { self[CryptoServiceKey.self] }
        set { self[CryptoServiceKey.self] = newValue }
    }
}
