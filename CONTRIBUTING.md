# Contributing to EnvHub

Thanks for your interest! EnvHub is a small, focused codebase — this page tells you
where things go and how to verify a change.

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
  `@concurrent` when they must leave the caller — filesystem walks, `git` spawns,
  scrypt, parsing many files. Offloading is a per-declaration, visible decision.
- Views and view-models are `@MainActor` (implicitly, in the app target). They call
  `Core`'s `@concurrent async` services from `.task`/`Task {}` — no `Task.detached`,
  no `DispatchQueue`.
- Everything crossing an actor boundary is a `Sendable` value type from `Model`.

## Build & test

```sh
swift test --package-path EnvHubKit    # the package: fast, UI-free — the logic tests
swift run --package-path EnvHubCLI envhub    # the CLI (its own package at EnvHubCLI/)

# the app
xcodebuild -project EnvHub/EnvHub.xcodeproj -scheme EnvHub \
  -destination 'platform=macOS' build
```

There is a headless smoke-test hook: launching the app with
`ENVHUB_ADD_PROJECT=/path/to/folder` auto-adds that folder as a project on startup.

## Pull requests

- New or changed `Core`/concern-module logic needs unit tests (Swift Testing —
  `@Test`, one suite per module in `EnvHubKit/Tests/`).
- `swift test --package-path EnvHubKit` and the `xcodebuild` build above must both pass.
- Parser changes must preserve the round-trip contract:
  `serialize(parse(text)) == text`, and untouched lines stay byte-stable through
  `applyEdits`.
- Crypto changes must keep the RFC 7914 scrypt vectors and envelope round-trip tests
  green; don't add third-party crypto dependencies.
- Keep the dependency policy: reputable, widely-used packages only (currently just
  `swift-argument-parser`).

## License

By contributing you agree that your contributions are licensed under the
[GPL-3.0](LICENSE), the project's license.
