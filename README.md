# EnvHub

[![Platform](https://img.shields.io/badge/platform-macOS%2026-blue)](#requirements)
[![Swift](https://img.shields.io/badge/swift-6-orange)](#architecture)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-green)](LICENSE)

A native **macOS 26 (Tahoe)** app — plus a companion CLI — that puts every `.env` file
on your machine in one window. A structured key/value editor (with an optional raw
"developer" view), Development / Staging / Production tabs, cross-project search, a
git-tracking guard, a cancellable filesystem scanner, side-by-side environment diffing,
and password-encrypted export/import.

Open source, **build-and-run from source**. No backend, no accounts, **no telemetry** —
everything is local. Your `.env` files on disk stay the single source of truth for
variable *values*; the app persists only its own metadata (via SwiftData). Inspired by
[Envly](https://www.envly.app), but original and open source.

---

## Screenshots

<!-- TODO before publishing: add screenshots to docs/screenshots/ and uncomment.
     Suggested shots (light or dark, ~1400px wide):
       docs/screenshots/editor.png   — the structured editor with masked values + tabs
       docs/screenshots/search.png   — cross-project search results
       docs/screenshots/scan.png     — the scanner sheet mid-scan
       docs/screenshots/diff.png     — side-by-side environment diff

<p align="center">
  <img src="docs/screenshots/editor.png" alt="EnvHub editor with environment tabs and masked values" width="720">
</p>
<p align="center">
  <img src="docs/screenshots/search.png" alt="Cross-project search" width="720">
</p>
-->

*Screenshots coming soon.*

## Features

- **Projects sidebar with workspaces** — every folder with `.env*` files, added manually
  or by scanning, organized into **Pinned**, your own **workspace sections**, and
  **Others** (each with a project count). Create/rename/delete workspaces, **drag
  projects onto a section header** to move them, or **multi-select** projects to move
  or remove them in bulk. Removing a project only forgets it in the app; it never
  deletes files on disk.
- **Structured editor** — a Key / Value / Comment / status table with inline edit and
  add/delete rows, plus a **raw "developer" view** to edit or copy the whole file as
  plain text. The **Comment column** is bound to the `# comment` line directly above
  each key: it shows it, edits it, adds it, or removes it — untouched lines stay
  byte-identical.
- **Cross-project search** — type `gemini` and see every project whose keys, values,
  filenames, or names match (e.g. `GEMINI_API_KEY`), grouped by project.
- **Git-tracking guard** — warns when a `.env` file is tracked by git and offers
  **Unstage & Ignore** (`git rm --cached` + add to `.gitignore`); manage `.gitignore`
  per file. **Example files are exempt** — `.env.example` is meant to be committed, so
  it never triggers the warning (and New File defaults it to *not* be gitignored).
- **Create env files** — make a new `.env`, `.env.production`, `.env.example`, or a
  custom name in any project (even one with no env files yet), optionally seeding keys
  from an existing file.
- **Pin & Finder** — pin projects to the top; right-click to Reveal / Open in Finder or
  copy the path. Per-file variable counts on the tabs.
- **Masking** — values are dots by default; reveal per-row (click the eye) or all at once.
  Safe to screen-share.
- **Inline validation** — non-blocking markers for duplicate keys, empty keys, and
  malformed lines (missing `=`, unbalanced quotes).
- **Environment tabs** — Development / Staging / Production / Local / Example / Other,
  driven by your own **editable, ordered regex rules** (first match wins; e.g.
  `.env.production.example` is an *Example*, `.env.development.local` is *Local*).
- **Faithful save** — writes a `.bak` backup of the current file first, then rewrites the
  real file **preserving comments and blank lines**, keeping untouched lines byte-stable.
- **Scanner** — pick folders (remembered) and optionally deep-scan recursively. The
  walk is **parallel** (many directories enumerated concurrently) and skips the trees
  that make home-directory scans slow (`~/Library`, `node_modules`, package-manager
  caches — the list is editable). **Stop & Review** ends a long scan early and shows
  everything found so far. Results that are **already in your sidebar are marked
  "Added" and skipped**, so re-scanning never duplicates projects, and accepted
  projects can land directly in a workspace.
- **Diff** — read-only side-by-side comparison of two environments: same / different /
  only-on-one-side.
- **Encrypted export / import** — `.envenc` files using **AES-256-GCM** with an **scrypt**
  key derivation. Export a single file or a whole project; import materializes the
  file(s) wherever you choose. Wrong passwords fail cleanly via the GCM auth tag.
- **CLI** — `scan`, `list`, `get`, `export`, `import`, and `workspace` on the exact
  same core. The CLI opens the **same store as the app**, so `envhub workspace …`
  lists, creates, and organizes the very sections you see in the sidebar.

## Requirements

- **macOS 26 (Tahoe)** and **Xcode 26+** (Swift 6.x).
- EnvHub runs **without the App Sandbox** so it can read `.env` files across your home
  directory. macOS may prompt for **Full Disk Access** the first time you scan protected
  locations (Desktop / Documents / Downloads); grant it in
  *System Settings → Privacy & Security → Full Disk Access*.

## Build & run

```sh
git clone https://github.com/cs4alhaider/EnvHub.git
cd EnvHub
```

### App

```sh
open EnvHub/EnvHub.xcodeproj    # then Run (⌘R) in Xcode
# …or from the command line:
xcodebuild -project EnvHub/EnvHub.xcodeproj -scheme EnvHub -destination 'platform=macOS' build
```

### CLI

```sh
swift run envhub --help
swift build -c release          # optimized build (scrypt is much faster)
cp .build/release/envhub /usr/local/bin/   # optional: put it on your PATH
```

### Tests (UI-free, fast)

```sh
swift test                      # 80 tests across all modules
```

## Architecture

One SwiftPM package (`EnvHubKit`) at the repo root holds **all** UI-free logic, the CLI,
and the tests. A thin SwiftUI app (`EnvHub/EnvHub.xcodeproj`) links it via a local
package reference (`../`) and consumes the `Core` and `Helper` products.

```
Package.swift                 EnvHubKit — libraries + CLI + tests
Sources/
  Model/        pure Sendable value types: EnvDocument/EnvVar/EnvKind, rules, diff,
                export payloads, masking — depends on nothing
  Parser/       .env read/write: parsing, serialization, edit reconciliation
                (comment/blank-line preserving, byte-stable untouched lines)  → Model
  Scanner/      cancellable filesystem discovery, glob matching, exclusions,
                throttled progress                                            → Model
  Classifier/   ordered regex rules → environment                             → Model
  Crypto/       AES-256-GCM (EnvCrypto) + in-house scrypt (RFC 7914),
                .envenc envelope                                              → Model
  Core/         the facade the app & CLI consume: services (scan/crypto),
                file save/create, git, search index, project metadata,
                SwiftData metadata store
  Helper/       SwiftUI @Environment injection of Core services (UI glue;
                the only package target importing SwiftUI)                    → Core
  envhub/       CLI executable — one file per subcommand                      → Core
Tests/          Swift Testing suites per module (UI-free): 80 tests
EnvHub/         SwiftUI macOS app (links Core + Helper), organized by feature:
  App/  Sidebar/  Project/  Editor/  Search/  Scan/  Diff/  Sharing/
  Settings/  Support/
```

Design principles:

- **All business logic lives in the package.** The app target is views + view-models
  only. Concern modules depend only on `Model`; `Core` is the single facade; `Helper`
  is the only package target that imports SwiftUI, so the CLI never links a UI
  framework.
- **Swift 6 strict concurrency, "approachable" style.** The app uses default
  `MainActor` isolation; the package enables `NonisolatedNonsendingByDefault`. Work
  that must leave the caller's actor — filesystem walks, `git` spawns, scrypt, bulk
  parsing — is explicitly marked `@concurrent` (`ScanService`, `CryptoService`,
  `GitService`, `SearchIndex.build`, `ProjectMetadata.load`), so views simply `await`
  and stay responsive. No `Task.detached`, no dispatch queues.
- **`.env` files are the source of truth for values.** SwiftData stores only app state
  (projects, workspaces, scan folders, exclusions, classification rules, preferences) —
  in one **shared store** (`~/Library/Application Support/EnvHub/EnvHub.store`) that the
  app and CLI both open, with projects deduplicated by canonical path (symlinks
  resolved, trailing slashes ignored).
- **Search is index-based.** Projects are read once into an in-memory `SearchIndex`
  (built off-main, with precomputed lowercase haystacks); per-keystroke search does no
  I/O and no re-lowercasing. The index also feeds the sidebar's file-count badges.
- **Git calls are batched.** Per-project status is three `git` spawns total
  (`rev-parse`, `ls-files`, `check-ignore --stdin`) regardless of file count.
- **Crypto is dependency-free and auditable** — scrypt is implemented in-house on
  CryptoKit's HMAC/AES primitives and validated against the official RFC 7914 test
  vectors; AES-256-GCM comes from CryptoKit.

## CLI reference

```sh
# Discover .env files, grouped by folder (‑‑deep to recurse)
envhub scan ~/Developer --deep

# List a project's files and variables (‑‑mask to hide values, ‑‑keys-only for keys)
envhub list ./my-app
envhub list ./my-app --mask

# Print one key's value (searches a file or a project folder)
envhub get DATABASE_URL --file ./my-app/.env
envhub get API_KEY --project ./my-app --mask

# Encrypt to .envenc (‑‑project for the whole folder; password prompted or from a file)
envhub export ./my-app/.env --out secrets.envenc
envhub export ./my-app --project --password-file ./pw.txt

# Decrypt a .envenc into a folder (‑‑force to overwrite)
envhub import secrets.envenc --into ./restored --force

# Workspaces — the same sidebar sections the app shows (shared store)
envhub workspace list
envhub workspace create Backend
envhub workspace move ./my-app Backend      # by path, or unique project name
envhub workspace sort Backend --by name     # name | path | date
envhub workspace rename Backend Services
envhub workspace delete Services            # projects move back to Others
```

The store lives at `~/Library/Application Support/EnvHub/EnvHub.store`; set
`ENVHUB_STORE=<path>` to point the app or CLI at a different one (useful for testing).

## How saving works

A **Save** writes `<file>.bak` (a copy of the current on-disk file) *before* overwriting
the real file. Edits are reconciled onto the original document so comments, blank lines,
and untouched entries are written back byte-for-byte; only changed/added/removed lines are
rewritten.

## The `.envenc` format

A `.envenc` file is a JSON envelope:

```json
{
  "version": 1,
  "type": "single | project",
  "kdf": "scrypt",
  "kdfParams": { "N": 32768, "r": 8, "p": 1 },
  "salt": "base64",
  "nonce": "base64",
  "ciphertext": "base64"
}
```

The plaintext payload (before encryption) is JSON describing the file(s) — each with its
key/value pairs and raw text for faithful materialization. The key is `scrypt(password,
salt)`; the payload is sealed with AES-256-GCM. `ciphertext` is the GCM ciphertext with
the 16-byte auth tag appended.

## Security notes

- No network access, no telemetry, no accounts. Nothing leaves your machine.
- Working `.env` files are stored as-is (no at-rest encryption) — encryption applies only
  to explicit `.envenc` export.
- Lost `.envenc` passwords are unrecoverable by design.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Add project | ⌘N |
| Scan for `.env` files | ⇧⌘F |
| Import `.envenc` | ⌘I |
| Save file | ⌘S |
| Settings | ⌘, |

## Roadmap

- **Cloud-provider import** (Vercel / Netlify / Railway / Fly): pull env vars straight
  from a provider into a local file using your own credentials, nothing routed through a
  server. The `EnvExport` / import layer is designed to accept a provider *source*
  without a rewrite.

Ideas and issues are welcome — see below.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) — the short version: business logic goes in the
Swift package with tests, the app stays a thin SwiftUI layer, and `swift test` +
`xcodebuild` must pass.

## License

[GPL-3.0](LICENSE) © [cs4alhaider](https://github.com/cs4alhaider).
