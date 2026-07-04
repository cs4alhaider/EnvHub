// The `Model` module holds EnvHub's pure, `Sendable` value types shared across every
// concern module, the macOS app, and the CLI:
//
//   • EnvKind        — Development / Staging / Production / Other
//   • EnvVar         — one editable key/value pair
//   • EnvFile        — one .env file on disk (path + classified kind)
//   • Project        — a folder containing one or more EnvFiles
//   • EnvDocument    — a faithfully-parsed .env file (EnvLine / EnvEntry)
//   • EnvDiagnostic  — duplicate-key / malformed-line warnings
//   • ClassificationRule / ScanConfig — editable settings
//
// SwiftData `@Model` persistence entities deliberately live in `Core`, not here, so
// this module stays value-type-only and usable from the CLI.
