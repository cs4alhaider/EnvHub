import Foundation
import Parser
import Scanner
import Classifier
import Crypto

// Surface the value-type domain model to every consumer of Core (app + CLI) without
// each having to import Model explicitly.
@_exported import Model

/// `Core` is the facade that ties the concern modules together for both the macOS app
/// and the `envhub` CLI. Services (scan, project store, crypto, save) and the SwiftData
/// metadata models are layered on in later milestones; this enum exposes build metadata.
public enum Core {
    /// EnvHub marketing/build version.
    public static let version = "0.1.0"

    /// Human-readable module name.
    public static let moduleName = "Core"

    /// The concern modules this facade ties together.
    public static let modules = ["Model", "Parser", "Scanner", "Classifier", "Crypto"]
}
