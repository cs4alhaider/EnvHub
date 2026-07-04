import Foundation

/// The environment a `.env` file belongs to. Files map into these via editable
/// classification rules (see `ClassificationRule`); anything unmatched is `.other`.
public enum EnvKind: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case development
    case staging
    case production
    case other

    public var id: String { rawValue }

    /// Human-readable title for tabs and headers.
    public var title: String {
        switch self {
        case .development: "Development"
        case .staging: "Staging"
        case .production: "Production"
        case .other: "Other"
        }
    }

    /// Stable display order (Dev → Staging → Prod → Other).
    public var sortOrder: Int {
        switch self {
        case .development: 0
        case .staging: 1
        case .production: 2
        case .other: 3
        }
    }
}
