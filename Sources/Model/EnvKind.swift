import Foundation

/// The environment a `.env` file belongs to. Files map into these via editable
/// classification rules (see `ClassificationRule`); anything unmatched is `.other`.
public enum EnvKind: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case development
    case staging
    case production
    /// Local overrides (`.env.local`, `.env.development.local`, …) — machine-specific,
    /// conventionally gitignored.
    case local
    /// Template files with placeholder values (`.env.example`, `.env.sample`, …) —
    /// conventionally **committed** so teammates know which keys a project needs.
    case example
    case other

    public var id: String { rawValue }

    /// Human-readable title for tabs and headers.
    public var title: String {
        switch self {
        case .development: "Development"
        case .staging: "Staging"
        case .production: "Production"
        case .local: "Local"
        case .example: "Example"
        case .other: "Other"
        }
    }

    /// Stable display order (Dev → Staging → Prod → Local → Example → Other).
    public var sortOrder: Int {
        switch self {
        case .development: 0
        case .staging: 1
        case .production: 2
        case .local: 3
        case .example: 4
        case .other: 5
        }
    }

    /// Whether files of this kind are *meant* to be committed. Example/template files
    /// carry placeholder values, so the app's git-tracking warning must not fire for
    /// them — everything else holding real values is a leak risk when tracked.
    public var isSafeToTrack: Bool { self == .example }
}
