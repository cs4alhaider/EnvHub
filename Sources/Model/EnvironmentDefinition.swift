import Foundation

/// A named color slot for environments — a fixed palette (rendered by the app) so
/// definitions stay a small, portable value.
public enum EnvColor: String, Codable, Sendable, Hashable, CaseIterable, Identifiable {
    case gray, red, orange, yellow, green, mint, teal, blue, indigo, purple, pink, brown

    public var id: String { rawValue }

    /// Human-readable name for pickers.
    public var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/// One user-defined environment: how a kind (slug) is titled, colored, ordered, and
/// treated by the git-tracking guard. The ordered list of these — edited in
/// Settings → Classification — is the source of truth for tabs, dots, and search
/// filters. Shipped defaults cover development/staging/production/local/example/other;
/// users add their own (UAT, pre-prod, …).
public struct EnvironmentDefinition: Codable, Hashable, Sendable, Identifiable {
    /// The stable slug this definition describes; also the identity.
    public var kind: EnvKind
    public var title: String
    public var color: EnvColor
    /// Whether files of this kind are *meant* to be committed (templates like
    /// `.env.example`) — such files never trigger the git-tracking warning.
    public var isSafeToTrack: Bool

    public var id: String { kind.rawValue }

    public init(kind: EnvKind, title: String, color: EnvColor, isSafeToTrack: Bool = false) {
        self.kind = kind
        self.title = title
        self.color = color
        self.isSafeToTrack = isSafeToTrack
    }

    /// The shipped set, in display order (tabs, dashboards, and search settings all
    /// follow this order; `other` stays last as the fallback bucket).
    public static let defaults: [EnvironmentDefinition] = [
        EnvironmentDefinition(kind: .development, title: "Development", color: .green),
        EnvironmentDefinition(kind: .staging, title: "Staging", color: .orange),
        EnvironmentDefinition(kind: .production, title: "Production", color: .red),
        EnvironmentDefinition(kind: .local, title: "Local", color: .blue),
        EnvironmentDefinition(kind: .example, title: "Example", color: .purple, isSafeToTrack: true),
        EnvironmentDefinition(kind: .other, title: "Other", color: .gray),
    ]
}

/// Fast lookups over an ordered `EnvironmentDefinition` list — the one object views
/// and the CLI consult for anything presentational about a kind. Kinds without a
/// definition (a rule pointing at a deleted environment) degrade gracefully:
/// capitalized-slug title, gray dot, sorted to the end, not safe to track.
public struct EnvironmentCatalog: Sendable, Hashable {
    /// Ordered definitions; always contains `other` (appended if missing) so the
    /// classifier's fallback bucket can't be configured away.
    public let definitions: [EnvironmentDefinition]
    private let byKind: [EnvKind: EnvironmentDefinition]
    private let orderByKind: [EnvKind: Int]

    public init(definitions: [EnvironmentDefinition]) {
        var list = definitions
        if !list.contains(where: { $0.kind == .other }) {
            list.append(EnvironmentDefinition(kind: .other, title: "Other", color: .gray))
        }
        self.definitions = list
        self.byKind = Dictionary(list.map { ($0.kind, $0) }, uniquingKeysWith: { first, _ in first })
        self.orderByKind = Dictionary(
            list.enumerated().map { ($0.element.kind, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// The shipped catalog — used before settings load and wherever settings aren't
    /// reachable (tests, CLI without a store).
    public static let builtin = EnvironmentCatalog(definitions: EnvironmentDefinition.defaults)

    public func definition(for kind: EnvKind) -> EnvironmentDefinition? { byKind[kind] }

    public func title(for kind: EnvKind) -> String {
        byKind[kind]?.title ?? kind.defaultTitle
    }

    public func color(for kind: EnvKind) -> EnvColor {
        byKind[kind]?.color ?? .gray
    }

    public func isSafeToTrack(_ kind: EnvKind) -> Bool {
        byKind[kind]?.isSafeToTrack ?? false
    }

    /// Position for display ordering; undefined kinds sort after everything defined.
    public func sortIndex(for kind: EnvKind) -> Int {
        orderByKind[kind] ?? definitions.count
    }

    /// All defined kinds, in display order.
    public var kinds: [EnvKind] { definitions.map(\.kind) }

    /// Sort arbitrary kinds into catalog display order (ties by slug for stability).
    public func sorted(_ kinds: some Sequence<EnvKind>) -> [EnvKind] {
        kinds.sorted {
            let left = sortIndex(for: $0)
            let right = sortIndex(for: $1)
            if left != right { return left < right }
            return $0.rawValue < $1.rawValue
        }
    }
}
