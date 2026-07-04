# Publishing the CLI independently — decision & plan

**Question:** should `envhub` (the CLI) move out of this repository and be published
as its own package?

**Recommendation: keep one repository, publish independent *artifacts*.** Ship the
CLI as its own installable thing (Homebrew formula + prebuilt binaries on GitHub
Releases) while the code stays here. Revisit a repo split at 1.0 (criteria below).

## Why not split the repo today

1. **The app and CLI share one SwiftData store** (`~/Library/Application
   Support/EnvHub/EnvHub.store`). The store schema (`ProjectRecord`,
   `WorkspaceRecord`, `AppSettings`, …) must match between whatever app version and
   CLI version a user has installed. Lockstep versions from one tag make that a
   non-issue; independent version streams turn every schema change into a
   compatibility matrix.
2. **Features span layers.** In practice a feature touches `Model` + `Core` + CLI +
   app together (workspaces did exactly this). One repo = one PR, one review, one
   tag. Two repos = a version-pin dance on every change while EnvHubKit's API is
   still moving.
3. **The CLI is already independent where it matters.** It is a standalone SwiftPM
   *product* (`swift build --product envhub`) that never links SwiftUI or the app.
   Nothing about installation requires Xcode's app target.

## What "independent publishing" looks like (this plan)

- **Tags on this repo** are the release unit: `v0.2.0`, `v0.3.0`, … One tag versions
  the app, the CLI, and the store schema together (`Core.version` mirrors it).
- **Each release attaches a CLI artifact**: `envhub-<version>-macos-arm64.tar.gz` —
  a release-built, Developer-ID-signed, notarized binary + `LICENSE` + the agent
  skill folder. Built with:

  ```sh
  swift build -c release --product envhub
  codesign --sign "Developer ID Application: <TEAM>" --options runtime --timestamp .build/release/envhub
  tar -czf envhub-<v>-macos-arm64.tar.gz -C .build/release envhub
  # notarize the tarball (see HOMEBREW.md), then: gh release upload v<v> …
  ```

- **Homebrew** installs it from the tap (see `HOMEBREW.md`): binary formula
  preferred (fast, no Xcode needed on the user's machine); a source-build formula is
  the fallback while there's no signing identity in CI.

## When a repo split becomes right

Split into `EnvHubKit` (library) + `envhub-cli` + app when **all** of these hold:

- EnvHubKit reaches a stable, semver-committed API (1.0) — including a *versioned*
  store schema with an explicit migration story between app/CLI versions;
- there are external consumers of EnvHubKit as a library (not just our two frontends);
- CLI release cadence genuinely diverges from the app's.

The mechanical split is then easy precisely because the boundaries already exist:
the CLI repo is a `Package.swift` depending on `EnvHubKit from: "1.0.0"` plus
`Sources/envhub` moved verbatim, and the Homebrew formula just changes its `url`.
