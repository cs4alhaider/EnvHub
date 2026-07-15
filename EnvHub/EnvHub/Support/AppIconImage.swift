import AppKit

extension NSImage {
    /// The app icon straight from this bundle's asset catalog. Preferred over
    /// `NSApp.applicationIconImage`, which resolves through LaunchServices and can
    /// serve a stale cached icon for the bundle identifier (e.g. right after the
    /// icon changed, or when another build of EnvHub is installed).
    @MainActor
    static var envHubIcon: NSImage {
        NSImage(named: "AppIcon") ?? NSApp.applicationIconImage
    }
}
