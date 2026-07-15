import Foundation

/// The environment a `.env` file belongs to — an **open** set, not a fixed enum, so
/// users can define their own (UAT, pre-prod, …) in Settings → Classification.
///
/// An `EnvKind` is just a stable slug (`"production"`, `"uat"`). Everything
/// presentational — display title, color, whether files of this kind are safe to
/// commit — lives in the user-editable `EnvironmentDefinition` list, resolved through
/// an `EnvironmentCatalog`. Files classify into kinds via `ClassificationRule`s;
/// anything unmatched is `.other`.
///
/// Encodes as a plain string (exactly like the enum it replaced), so stored rules,
/// `.envenc` exports, and settings from older versions decode unchanged.
public struct EnvKind: RawRepresentable, Hashable, Sendable, Identifiable {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var id: String { rawValue }

    /// Fallback display title when a kind has no definition in the catalog (e.g. a
    /// rule still points at a deleted custom environment): the capitalized slug.
    public var defaultTitle: String {
        guard let first = rawValue.first else { return rawValue }
        return first.uppercased() + rawValue.dropFirst()
    }

    /// Make a slug for a user-entered environment name: lowercased, alphanumerics
    /// kept, everything else collapsed to single dashes ("Pre Prod!" → "pre-prod").
    public static func slug(from name: String) -> EnvKind {
        var slug = ""
        var lastWasDash = true   // suppress leading dashes
        for character in name.lowercased() {
            if character.isLetter || character.isNumber {
                slug.append(character)
                lastWasDash = false
            } else if !lastWasDash {
                slug.append("-")
                lastWasDash = true
            }
        }
        while slug.hasSuffix("-") { slug.removeLast() }
        return EnvKind(rawValue: slug.isEmpty ? "environment" : slug)
    }

    // MARK: Built-in kinds (the shipped defaults; users can add more)

    public static let development = EnvKind(rawValue: "development")
    public static let staging = EnvKind(rawValue: "staging")
    public static let production = EnvKind(rawValue: "production")
    public static let local = EnvKind(rawValue: "local")
    public static let example = EnvKind(rawValue: "example")
    /// The fallback for unmatched files — always present, never deletable.
    public static let other = EnvKind(rawValue: "other")
}

/// Encodes as a bare string — identical wire/storage format to the enum this type
/// replaced (RawRepresentable synthesis would produce `{"rawValue": …}`, which is why
/// this is manual).
extension EnvKind: Codable {
    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
