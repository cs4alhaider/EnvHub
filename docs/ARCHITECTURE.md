# Architecture

One SwiftPM package (`EnvHubKit/`) holds **all** UI-free logic and the tests. A thin
SwiftUI app links it via a local package reference and consumes the `Core` and `Helper`
products; the `envhub` CLI is its own small package at `EnvHubCLI/`, built on `Core`.

```
EnvHubKit/                    the Swift package — libraries + tests
  Package.swift
  Sources/
    Model/      pure Sendable value types (EnvDocument, EnvKind + catalog, diff, …)
    Parser/     .env read/write — comment-preserving, byte-stable          → Model
    Scanner/    parallel, cancellable filesystem discovery                 → Model
    Classifier/ ordered regex rules → environment                          → Model
    Crypto/     AES-256-GCM + in-house scrypt (RFC 7914), .envenc          → Model
    Core/       facade + services + shared SwiftData store (app & CLI)
    Helper/     SwiftUI @Environment injection of Core services            → Core
  Tests/        Swift Testing suites per module (UI-free)
EnvHub/         SwiftUI macOS app (links Core + Helper)
EnvHubCLI/      envhub CLI package — one file per subcommand               → Core
```

## Design principles

- **All business logic lives in the package** — the app target is views + view-models only.
  Concern modules depend only on `Model`; `Core` is the single facade; `Helper` is the only
  package target that imports SwiftUI, so the CLI never links a UI framework.
- **Swift 6 strict concurrency.** Work that must leave the caller's actor — filesystem
  walks, scrypt, bulk parsing — is explicitly `@concurrent`, so views simply `await` and
  stay responsive.
- **Your `.env` files are the source of truth.** SwiftData stores only app state (projects,
  workspaces, rules, preferences) in one shared store the app and CLI both open.
- **Crypto is dependency-free and auditable** — scrypt is implemented in-house on CryptoKit
  primitives and validated against the official RFC 7914 vectors.
- **One dependency total** (`swift-argument-parser`, CLI only) — reputable, widely-used
  packages only.

## How saving works

A **Save** writes `<file>.bak` (a copy of the current on-disk file) *before* overwriting the
real file. Edits are reconciled onto the original document so comments, blank lines, and
untouched entries are written back byte-for-byte; only changed/added/removed lines are
rewritten. CRLF line endings survive round trips.

## The two build flavors

The App Store edition runs in the App Sandbox (folder access via user grants +
security-scoped bookmarks); unsandboxed **source builds** additionally get whole-disk
scanning, git integration, and the bundled-CLI installer. Both are the same codebase —
behavior is keyed at runtime on `AppSandbox.isActive`, so there is exactly one code path
to test.
