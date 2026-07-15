import Foundation

/// Central place for turning secret values into mask dots, shared by the app's
/// editor/diff/search views and the CLI's `--mask` flag so masking behaves the
/// same everywhere.
public enum ValueMasking {
    /// A masked representation of `value`.
    ///
    /// The dot count loosely tracks the value's length (so a long token still *looks*
    /// long) but is clamped to `3...maxDots`: the floor stops a 1-character value from
    /// revealing its exact length, and the ceiling keeps very long secrets from
    /// blowing up row layouts. Empty values stay empty — there is nothing to hide.
    ///
    /// - Parameter maxDots: The dot ceiling; callers pick what fits their layout
    ///   (wide editor rows use more, compact CLI output uses fewer).
    public static func masked(_ value: String, maxDots: Int = 20) -> String {
        value.isEmpty ? "" : String(repeating: "•", count: min(max(value.count, 3), maxDots))
    }
}
