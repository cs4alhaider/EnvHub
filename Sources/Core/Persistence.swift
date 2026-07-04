import Foundation
import SwiftData

// SwiftData metadata store — the record types only. The `.env` files on disk remain
// the single source of truth for variable *values*; SwiftData persists only app state:
// the projects list, workspaces, scan folders, exclusions, classification rules, and
// UI preferences. Container construction + operations live in `EnvHubStore`,
// `ProjectStore`, and `WorkspaceStore`.

/// A folder the user has added as a project. Removing it only forgets the project in
/// the app; it never touches files on disk.
@Model
public final class ProjectRecord {
    public var id: UUID
    public var name: String
    /// Absolute filesystem path of the folder.
    public var path: String
    public var dateAdded: Date
    /// Pinned projects surface in the sidebar's Pinned section. Defaulted so existing
    /// stores migrate automatically.
    public var isPinned: Bool = false
    /// The workspace (sidebar section) this project belongs to; `nil` = the ungrouped
    /// "Others" section. A UUID reference (not a SwiftData relationship) keeps the
    /// schema migration lightweight and the records decoupled.
    public var workspaceID: UUID? = nil
    /// Manual position within its section (see `WorkspaceStore.ordered`): lower comes
    /// first, ties fall back to name order. 0 for everything = plain name order.
    public var sortOrder: Int = 0

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        dateAdded: Date = .now,
        isPinned: Bool = false,
        workspaceID: UUID? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.dateAdded = dateAdded
        self.isPinned = isPinned
        self.workspaceID = workspaceID
        self.sortOrder = sortOrder
    }

    public var url: URL { URL(filePath: path) }
}

/// A named sidebar section the user can group projects into (and that the CLI can
/// create and organize — the store is shared between app and CLI).
@Model
public final class WorkspaceRecord {
    public var id: UUID
    public var name: String
    /// Position among workspaces in the sidebar (creation order by default).
    public var sortOrder: Int
    public var dateAdded: Date

    public init(id: UUID = UUID(), name: String, sortOrder: Int = 0, dateAdded: Date = .now) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.dateAdded = dateAdded
    }
}

/// A root folder the user chose to scan (remembered across launches).
@Model
public final class ScanFolderRecord {
    public var path: String
    public var dateAdded: Date

    public init(path: String, dateAdded: Date = .now) {
        self.path = path
        self.dateAdded = dateAdded
    }

    public var url: URL { URL(filePath: path) }
}

/// Singleton-row application settings. Classification rules are stored as encoded JSON
/// so the schema stays simple and robust.
@Model
public final class AppSettings {
    public var maskByDefault: Bool
    public var deepScanDefault: Bool
    public var filenamePatterns: [String]
    public var exclusions: [String]
    private var classificationRulesData: Data

    public init(
        maskByDefault: Bool = true,
        deepScanDefault: Bool = false,
        filenamePatterns: [String] = ScanConfig.defaultFilenamePatterns,
        exclusions: [String] = ScanConfig.defaultExclusions,
        classificationRules: [ClassificationRule] = ClassificationRule.defaults
    ) {
        self.maskByDefault = maskByDefault
        self.deepScanDefault = deepScanDefault
        self.filenamePatterns = filenamePatterns
        self.exclusions = exclusions
        self.classificationRulesData = (try? JSONEncoder().encode(classificationRules)) ?? Data()
    }

    /// Ordered classification rules (decoded from storage; falls back to defaults).
    public var classificationRules: [ClassificationRule] {
        get { (try? JSONDecoder().decode([ClassificationRule].self, from: classificationRulesData)) ?? ClassificationRule.defaults }
        set { classificationRulesData = (try? JSONEncoder().encode(newValue)) ?? classificationRulesData }
    }

    /// A value-type snapshot of the scan-related settings.
    public var scanConfig: ScanConfig {
        ScanConfig(filenamePatterns: filenamePatterns, exclusions: exclusions, deepScan: deepScanDefault)
    }
}
