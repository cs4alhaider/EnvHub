import Foundation

/// Runtime App Sandbox awareness. EnvHub ships in two editions from one codebase:
/// the Developer ID / Homebrew build runs unsandboxed (scan anything, spawn git,
/// bundle the CLI), while the App Store build runs sandboxed. Behavior differences
/// are keyed on this runtime check, not compile-time flags, so there is exactly one
/// code path to test.
public enum AppSandbox {
    /// True when the process runs inside the macOS App Sandbox (the App Store
    /// edition, or any build signed with the sandbox entitlement).
    public static let isActive: Bool =
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
}

/// Security-scoped bookmarks — how the sandboxed edition keeps access to project
/// folders across launches. The user grants a folder once (open panel, scan root);
/// we store a bookmark on the `ProjectRecord` and re-arm it at launch.
///
/// Outside the sandbox everything here is a deliberate no-op: paths just work.
public enum SecurityScopedBookmarks {
    /// A bookmark for a folder the user granted via panel/drag (or any URL already
    /// within an active scope). Returns nil outside the sandbox — not needed there.
    public static func make(for url: URL) -> Data? {
        guard AppSandbox.isActive else { return nil }
        return try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// The result of arming a stored bookmark.
    public enum Access: Sendable {
        /// Unsandboxed — no bookmark needed, use the path directly.
        case notNeeded
        /// Access granted. When `refreshedBookmark` is non-nil the stored bookmark
        /// was stale and this fresh one should be persisted in its place.
        case granted(URL, refreshedBookmark: Data?)
        /// No usable bookmark — the user must re-grant the folder via a panel.
        case denied
    }

    /// Resolve a stored bookmark and start accessing it. Access is intentionally
    /// kept for the app's lifetime — project folders are the app's whole job, and
    /// the per-process scope limit is far above any realistic library size.
    public static func startAccess(_ data: Data?) -> Access {
        guard AppSandbox.isActive else { return .notNeeded }
        guard let data else { return .denied }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return .denied }
        guard url.startAccessingSecurityScopedResource() else { return .denied }
        // Stale but working: hand back a refreshed bookmark (creating one is
        // possible while the scope is active) so the caller can persist it.
        return .granted(url, refreshedBookmark: isStale ? make(for: url) : nil)
    }
}
