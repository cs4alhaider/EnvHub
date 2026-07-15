# Contributing to EnvHub

Thanks for your interest! EnvHub is a small, focused codebase — this guide gets you
from clone to merged PR: how to build, where things go, and how to verify a change.

## Getting started (build from source)

You need **macOS 26 (Tahoe)** and **Xcode 26+** (Swift 6.x). No other setup.

```sh
git clone https://github.com/cs4alhaider/EnvHub.git
cd EnvHub

# The app — open in Xcode and Run (⌘R)
open EnvHub/EnvHub.xcodeproj
# …or headless:
xcodebuild -project EnvHub/EnvHub.xcodeproj -scheme EnvHub \
  -destination 'platform=macOS' build

# The package tests (fast, UI-free — this is where the logic tests live)
swift test --package-path EnvHubKit

# The CLI
swift run --package-path EnvHubCLI envhub --help
swift build -c release --package-path EnvHubCLI   # optimized (scrypt is much faster)
```

Tip: point a scratch store at your dev builds so you never touch your real library:
`ENVHUB_STORE=/tmp/envhub-dev.store swift run --package-path EnvHubCLI envhub workspace list`.
There's also a headless smoke-test hook — launching the app with
`ENVHUB_ADD_PROJECT=/path/to/folder` auto-adds that folder on startup.

Note: source builds run **unsandboxed** and include extras the App Store edition
hides (whole-disk scanning, git integration, the bundled-CLI installer). Behavior is
keyed at runtime on `AppSandbox.isActive` — keep both paths working.

## Repo layout

```
EnvHubKit/     the Swift package — all UI-free logic + tests
EnvHub/        the SwiftUI macOS app (views + view-models only)
EnvHubCLI/     the envhub CLI (its own package, consumes Core)
docs/          architecture, CLI reference, security, branding, features inventory
skills/        the envhub-cli agent skill (for AI coding agents)
appstore-kit/  App Store submission assets
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the module graph and design
principles.

## The one architecture rule

**All business logic lives in the Swift package (`EnvHubKit/`), never in the Xcode
project.** The app target (`EnvHub/EnvHub/`) contains SwiftUI views and view-models
only — thin state + glue that calls `Core`. If a change involves parsing, scanning,
classification, crypto, git, persistence, searching, or anything else that could
conceivably run without a UI, it belongs in `EnvHubKit/Sources/` with a unit test next
to it in `EnvHubKit/Tests/`. A good smell test: *could the CLI use this?* Then it goes
in the package.

Module boundaries (enforced by the package manifest):

- `Model` — pure `Sendable` value types. Depends on nothing.
- `Parser`, `Scanner`, `Classifier`, `Crypto` — concern modules. Depend **only** on `Model`.
- `Core` — the facade the app and CLI consume; also holds the SwiftData metadata models.
- `Helper` — SwiftUI `@Environment` injection of Core's services. The **only** package
  target that may import SwiftUI (so the CLI never links a UI framework).
- `envhub` — the CLI; its own small package at `EnvHubCLI/`, a thin argument-parsing
  shell over `Core`.

## Concurrency conventions

The package enables the `NonisolatedNonsendingByDefault` upcoming feature and the app
target uses Swift 6 language mode with default `MainActor` isolation (Xcode's
"approachable concurrency"). In practice:

- A plain `async` function runs on its **caller's** actor. Mark package functions
  `@concurrent` when they must leave the caller — filesystem walks, scrypt, parsing
  many files. Offloading is a per-declaration, visible decision.
- Views and view-models are `@MainActor` (implicitly, in the app target). They call
  `Core`'s `@concurrent async` services from `.task`/`Task {}` — no `Task.detached`,
  no `DispatchQueue`.
- Everything crossing an actor boundary is a `Sendable` value type from `Model`.

## Testing

- Framework: **Swift Testing** (`@Test`/`#expect`), one suite per module in
  `EnvHubKit/Tests/`.
- New or changed `Core`/concern-module logic needs unit tests.
- Two contracts are sacred:
  - **Parser round-trip**: `serialize(parse(text)) == text`, and untouched lines stay
    byte-stable through `applyEdits`.
  - **Crypto**: the RFC 7914 scrypt vectors and envelope round-trip tests stay green.

## Pull requests

1. Fork, branch from `main`, keep the change focused.
2. `swift test --package-path EnvHubKit` and the `xcodebuild` build above must both pass.
3. Add tests for package-level changes; update docs (`README.md`, `docs/…`) when
   behavior or commands change.
4. Don't add dependencies — the policy is reputable, widely-used packages only, and the
   current count is exactly one (`swift-argument-parser`, CLI only). Crypto stays
   in-house on CryptoKit.
5. Describe *why* in the PR body; screenshots for UI changes are appreciated
   (`docs/…` has the capture conventions).

## Bugs & ideas

- Bugs → [open an issue](https://github.com/cs4alhaider/EnvHub/issues/new) with macOS
  version + steps; never paste real secret values into an issue.
- Feature ideas welcome — an environment type EnvHub doesn't have yet, a CLI verb, an
  editor nicety. Small, sharp proposals merge fastest.

## License

By contributing you agree that your contributions are licensed under the
[GPL-3.0](LICENSE), the project's license.
