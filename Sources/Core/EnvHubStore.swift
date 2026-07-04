import Foundation
import SwiftData

/// Central place to build the SwiftData container and fetch-or-create the settings row.
///
/// The store lives at an **explicit, well-known URL** (`~/Library/Application
/// Support/EnvHub/EnvHub.store`) so the app and the `envhub` CLI open the *same*
/// database — that's what lets the CLI list and organize the workspaces you see in
/// the sidebar. Earlier versions used SwiftData's implicit default location; the
/// first open after upgrading imports that legacy data once (see
/// `importLegacyStore`).
public enum EnvHubStore {
    public static let models: [any PersistentModel.Type] = [
        ProjectRecord.self, WorkspaceRecord.self, ScanFolderRecord.self, AppSettings.self,
    ]

    public static var schema: Schema { Schema(models) }

    /// Where the shared app/CLI store lives. `ENVHUB_STORE=<path>` overrides it —
    /// useful for testing against an isolated store or keeping separate setups.
    public static var storeURL: URL {
        if let override = ProcessInfo.processInfo.environment["ENVHUB_STORE"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return URL.applicationSupportDirectory.appending(path: "EnvHub/EnvHub.store")
    }

    /// SwiftData's implicit location, used by EnvHub before the store moved to
    /// `storeURL` (kept only for the one-time import).
    static var legacyStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "default.store")
    }

    /// Builds the shared `ModelContainer`. `inMemory` is used by tests.
    public static func container(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [configuration])
        }

        let url = storeURL
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Import from the legacy location exactly once: only when the new store file
        // doesn't exist yet (i.e. the first launch after upgrading).
        let fm = FileManager.default
        let shouldImportLegacy = !fm.fileExists(atPath: url.path(percentEncoded: false))
            && fm.fileExists(atPath: legacyStoreURL.path(percentEncoded: false))

        let configuration = ModelConfiguration(schema: schema, url: url)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        if shouldImportLegacy {
            try? importLegacyStore(from: legacyStoreURL, into: container)
        }
        // Merge any duplicate project records left over from before paths were
        // canonicalized (a no-op on clean stores).
        ProjectStore.cleanupDuplicates(in: ModelContext(container))
        return container
    }

    /// Copies every EnvHub record out of a store at `legacyURL` into `container`.
    /// The legacy store itself is left in place (it may be SwiftData's shared default
    /// location, so deleting it is not ours to do).
    static func importLegacyStore(from legacyURL: URL, into container: ModelContainer) throws {
        let legacyContainer = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: legacyURL)]
        )
        let source = ModelContext(legacyContainer)
        let destination = ModelContext(container)

        for p in (try? source.fetch(FetchDescriptor<ProjectRecord>())) ?? [] {
            destination.insert(ProjectRecord(
                id: p.id, name: p.name, path: p.path, dateAdded: p.dateAdded,
                isPinned: p.isPinned, workspaceID: p.workspaceID, sortOrder: p.sortOrder
            ))
        }
        for w in (try? source.fetch(FetchDescriptor<WorkspaceRecord>())) ?? [] {
            destination.insert(WorkspaceRecord(
                id: w.id, name: w.name, sortOrder: w.sortOrder, dateAdded: w.dateAdded))
        }
        for f in (try? source.fetch(FetchDescriptor<ScanFolderRecord>())) ?? [] {
            destination.insert(ScanFolderRecord(path: f.path, dateAdded: f.dateAdded))
        }
        if let s = (try? source.fetch(FetchDescriptor<AppSettings>()))?.first {
            destination.insert(AppSettings(
                maskByDefault: s.maskByDefault,
                deepScanDefault: s.deepScanDefault,
                filenamePatterns: s.filenamePatterns,
                exclusions: s.exclusions,
                classificationRules: s.classificationRules
            ))
        }
        try destination.save()
    }

    /// Returns the single `AppSettings` row, creating it on first use.
    @MainActor
    public static func settings(in context: ModelContext) -> AppSettings {
        if let existing = try? context.fetch(FetchDescriptor<AppSettings>()).first {
            migrateDefaultRulesIfNeeded(existing)
            migrateDefaultExclusionsIfNeeded(existing)
            return existing
        }
        let created = AppSettings()
        context.insert(created)
        return created
    }

    /// Upgrades a stored exclusion list that is *exactly* the old shipped default to
    /// the expanded default (Library, package-manager caches, …). A customized list
    /// is never rewritten.
    @MainActor
    static func migrateDefaultExclusionsIfNeeded(_ settings: AppSettings) {
        guard settings.exclusions == ScanConfig.legacyDefaultExclusions else { return }
        settings.exclusions = ScanConfig.defaultExclusions
    }

    /// Upgrades a stored ruleset that is *exactly* the pre-Local/Example defaults to
    /// the current defaults (which add the `example` and `local` rules). A ruleset the
    /// user has customized in any way is left alone — they can always use "Reset to
    /// Defaults" in Settings.
    @MainActor
    static func migrateDefaultRulesIfNeeded(_ settings: AppSettings) {
        let stored = settings.classificationRules
        let legacy = ClassificationRule.legacyDefaults
        guard stored.count == legacy.count,
              zip(stored, legacy).allSatisfy({
                  $0.pattern == $1.pattern && $0.kind == $1.kind && $0.isEnabled == $1.isEnabled
              })
        else { return }
        settings.classificationRules = ClassificationRule.defaults
    }
}
