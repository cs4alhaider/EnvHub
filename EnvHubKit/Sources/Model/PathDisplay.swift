import Foundation

/// Compact path presentation for UI rows: drops the home-directory prefix so a
/// project path leads with the parts that actually identify it
/// ("/Users/me/Documents/GitHub/app" → "Documents/GitHub/app"). Views pair this
/// with head truncation so the *end* of the path stays visible when space runs out.
public enum PathDisplay {
    /// `path` with the home-directory prefix removed. The home folder itself becomes
    /// "~"; paths outside the home directory are returned unchanged.
    public static func homeRelative(_ path: String, home: String = NSHomeDirectory()) -> String {
        var home = home
        while home.count > 1 && home.hasSuffix("/") { home.removeLast() }
        guard home.count > 1 else { return path }
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return String(path.dropFirst(home.count + 1))
        }
        return path
    }
}
