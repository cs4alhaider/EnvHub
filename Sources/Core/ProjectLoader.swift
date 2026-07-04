import Foundation
import Classifier

/// Loads a project's `.env` files from disk and classifies them into environments,
/// used by the app's environment tabs and the CLI.
public enum ProjectLoader {
    /// The classified env files directly inside `folder`, sorted by filename.
    public static func envFiles(
        in folder: URL,
        rules: [ClassificationRule],
        patterns: [String] = ScanConfig.defaultFilenamePatterns
    ) -> [EnvFile] {
        EnvFileLister.envFiles(in: folder, patterns: patterns).map { EnvClassifier.envFile(at: $0, rules: rules) }
    }

    /// The env files grouped by environment.
    public static func grouped(
        in folder: URL,
        rules: [ClassificationRule],
        patterns: [String] = ScanConfig.defaultFilenamePatterns
    ) -> [EnvKind: [EnvFile]] {
        Dictionary(grouping: envFiles(in: folder, rules: rules, patterns: patterns), by: \.kind)
    }

    /// Classify a single filename (Core-level passthrough so the app, which links only
    /// `Core`, can classify without importing the internal `Classifier` target).
    public static func classify(fileName: String, rules: [ClassificationRule]) -> EnvKind {
        EnvClassifier.classify(fileName: fileName, rules: rules)
    }
}
