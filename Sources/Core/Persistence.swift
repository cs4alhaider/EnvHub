import Foundation
import SwiftData

// SwiftData metadata store. The `.env` files on disk remain the single source of truth
// for variable *values*; SwiftData persists only app state — the projects list, scan
// folders, exclusions, classification rules, and UI preferences.

/// A folder the user has added as a project. Removing it only forgets the project in
/// the app; it never touches files on disk.
@Model
public final class ProjectRecord {
    public var id: UUID
    public var name: String
    /// Absolute filesystem path of the folder.
    public var path: String
    public var dateAdded: Date
    /// Pinned projects sort to the top of the sidebar. Defaulted so existing stores
    /// migrate automatically.
    public var isPinned: Bool = false

    public init(id: UUID = UUID(), name: String, path: String, dateAdded: Date = .now, isPinned: Bool = false) {
        self.id = id
        self.name = name
        self.path = path
        self.dateAdded = dateAdded
        self.isPinned = isPinned
    }

    public var url: URL { URL(filePath: path) }
}

/// A root folder the user chose to scan (remembered across launches). Used by the
/// scanner in milestone 6.
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

/// Central place to build the SwiftData container and fetch-or-create the settings row.
public enum EnvHubStore {
    public static let models: [any PersistentModel.Type] = [
        ProjectRecord.self, ScanFolderRecord.self, AppSettings.self,
    ]

    public static var schema: Schema { Schema(models) }

    /// Builds the app's `ModelContainer`. `inMemory` is used by tests.
    public static func container(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Returns the single `AppSettings` row, creating it on first use.
    @MainActor
    public static func settings(in context: ModelContext) -> AppSettings {
        if let existing = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            return existing
        }
        let created = AppSettings()
        context.insert(created)
        return created
    }
}

/// Project operations kept out of the views (business logic lives in the package).
public enum ProjectStore {
    /// Adds a folder as a project, ignoring duplicates by path. Never modifies disk.
    @MainActor
    @discardableResult
    public static func addProject(at url: URL, to context: ModelContext) -> ProjectRecord? {
        let path = url.path(percentEncoded: false)
        let existing = (try? context.fetch(FetchDescriptor<ProjectRecord>())) ?? []
        if existing.contains(where: { $0.path == path }) { return nil }
        let record = ProjectRecord(name: url.lastPathComponent, path: path)
        context.insert(record)
        return record
    }

    /// Forgets a project in the app. Files on disk are untouched.
    @MainActor
    public static func remove(_ record: ProjectRecord, from context: ModelContext) {
        context.delete(record)
    }

    /// Pin or unpin a project (pinned projects sort to the top).
    @MainActor
    public static func setPinned(_ record: ProjectRecord, _ pinned: Bool) {
        record.isPinned = pinned
    }
}
