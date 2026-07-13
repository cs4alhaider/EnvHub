import Foundation

/// One ordered filename → environment rule. The classifier applies enabled rules in
/// order and the first whose `pattern` (a regular expression) matches the filename
/// wins; unmatched files fall into `.other`. Editable/reorderable in Settings.
public struct ClassificationRule: Identifiable, Sendable, Hashable, Codable {
    public var id: UUID
    /// A regular expression matched (case-insensitively) against the filename.
    public var pattern: String
    /// The environment a match maps to.
    public var kind: EnvKind
    public var isEnabled: Bool

    public init(id: UUID = UUID(), pattern: String, kind: EnvKind, isEnabled: Bool = true) {
        self.id = id
        self.pattern = pattern
        self.kind = kind
        self.isEnabled = isEnabled
    }

    /// Shipped defaults (ordered, first match wins). Example must come first so
    /// `.env.production.example` reads as an example, not production; local next so
    /// `.env.development.local` reads as a local override.
    public static var defaults: [ClassificationRule] {
        [
            ClassificationRule(pattern: "example|sample|template", kind: .example),
            ClassificationRule(pattern: "local", kind: .local),
            ClassificationRule(pattern: "prod|production", kind: .production),
            ClassificationRule(pattern: "stag|staging", kind: .staging),
            ClassificationRule(pattern: "dev|development|^\\.env$", kind: .development),
        ]
    }
}

/// Configuration for filesystem discovery — filename patterns, the excluded directory
/// list (pre-populated with common noise dirs), and whether deep (recursive) scanning
/// is on by default. Editable in Settings.
public struct ScanConfig: Sendable, Hashable, Codable {
    /// Glob-style filename patterns to match, e.g. `.env`, `.env.*`.
    public var filenamePatterns: [String]
    /// Directory names to skip while walking the tree.
    public var exclusions: [String]
    /// Whether a scan recurses into subdirectories.
    public var deepScan: Bool

    public init(filenamePatterns: [String], exclusions: [String], deepScan: Bool) {
        self.filenamePatterns = filenamePatterns
        self.exclusions = exclusions
        self.deepScan = deepScan
    }

    /// Default excluded directories: build output, dependency checkouts, and the big
    /// cache/system trees that dominate a home-directory scan (`~/Library` alone is
    /// typically hundreds of thousands of folders with no `.env` files in them).
    /// Fully editable in Settings → Scanning.
    public static let defaultExclusions = [
        // Dependencies & build output
        "node_modules", ".git", ".next", "dist", "build", ".build",
        ".venv", "venv", "Pods", "DerivedData", ".cache",
        // System / cache trees that make home-directory scans slow
        "Library", ".Trash",
        // Package-manager and toolchain caches
        ".npm", ".nvm", ".pnpm-store", ".yarn", ".cargo", ".rustup",
        ".gradle", ".m2", ".cocoapods", ".gem", ".docker", ".vscode",
    ]

    /// Default filename patterns: a bare `.env` plus `.env.<anything>`.
    public static let defaultFilenamePatterns = [".env", ".env.*"]

    public static let `default` = ScanConfig(
        filenamePatterns: defaultFilenamePatterns,
        exclusions: defaultExclusions,
        deepScan: false
    )
}
