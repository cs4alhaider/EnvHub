import Foundation
import Model

/// Maps a filename to an `EnvKind` using an ordered list of editable regex rules:
/// enabled rules are tried in order and the first whose pattern matches (case-
/// insensitively) wins; anything unmatched falls into `.other`.
public enum EnvClassifier {
    /// Classify a filename with the given ordered rules.
    public static func classify(fileName: String, rules: [ClassificationRule]) -> EnvKind {
        for rule in rules where rule.isEnabled {
            if matches(fileName: fileName, pattern: rule.pattern) {
                return rule.kind
            }
        }
        return .other
    }

    /// Build a classified `EnvFile` from a URL.
    public static func envFile(at url: URL, rules: [ClassificationRule]) -> EnvFile {
        EnvFile(path: url, kind: classify(fileName: url.lastPathComponent, rules: rules))
    }

    /// Whether a filename matches a single regex pattern (case-insensitive). An invalid
    /// pattern simply never matches (so a half-typed rule in Settings can't crash).
    public static func matches(fileName: String, pattern: String) -> Bool {
        guard !pattern.isEmpty,
              let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        else { return false }
        let range = NSRange(fileName.startIndex..<fileName.endIndex, in: fileName)
        return regex.firstMatch(in: fileName, options: [], range: range) != nil
    }
}
