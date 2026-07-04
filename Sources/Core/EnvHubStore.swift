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

    /// The EnvHub data directory (holds the store and the CLI↔app hand-off file).
    public static var supportDirectory: URL {
        storeURL.deletingLastPathComponent()
    }

    /// A tiny hand-off file the CLI writes (`envhub .`) and the app consumes on
    /// activation to open a folder — see ``writePendingOpen(_:)`` / ``consumePendingOpen()``.
    static var pendingOpenURL: URL {
        supportDirectory.appending(path: "pending-open.txt")
    }

    /// CLI side of `envhub .`: record a folder for the app to open next time it
    /// activates. Writing the *canonical* path keeps it consistent with stored projects.
    public static func writePendingOpen(_ folder: URL) throws {
        try? FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        try ProjectStore.canonicalPath(for: folder).write(to: pendingOpenURL, atomically: true, encoding: .utf8)
    }

    /// App side of `envhub .`: read and clear any pending open request. Returns the
    /// folder URL, or `nil` when there's nothing waiting.
    public static func consumePendingOpen() -> URL? {
        let url = pendingOpenURL
        guard let path = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        try? FileManager.default.removeItem(at: url)
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : URL(filePath: trimmed)
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

    /// Erases everything EnvHub knows (Settings → Data → Reset EnvHub): projects,
    /// workspaces, scan folders, and preferences. Files on disk are never touched.
    /// The settings row is recreated with defaults on next access, so the welcome
    /// flow shows again.
    public static func reset(in context: ModelContext) {
        func deleteAll<T: PersistentModel>(_ type: T.Type) {
            for record in (try? context.fetch(FetchDescriptor<T>())) ?? [] {
                context.delete(record)
            }
        }
        deleteAll(ProjectRecord.self)
        deleteAll(WorkspaceRecord.self)
        deleteAll(ScanFolderRecord.self)
        deleteAll(AppSettings.self)
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
