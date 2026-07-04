# EnvHub

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

## Features

- **Projects sidebar** — every folder with `.env*` files, added manually or by scanning.
  Removing a project only forgets it in the app; it never deletes files on disk.
- **Structured editor** — a Key / Value / status table with inline edit and add/delete
  rows, plus a **raw "developer" view** to edit or copy the whole file as plain text.
- **Cross-project search** — type `gemini` and see every project whose keys, values,
  filenames, or names match (e.g. `GEMINI_API_KEY`), grouped by project.
- **Git-tracking guard** — warns when a `.env` file is tracked by git and offers
  **Unstage & Ignore** (`git rm --cached` + add to `.gitignore`); manage `.gitignore`
  per file (leave `.env.example` committed).
- **Create env files** — make a new `.env`, `.env.production`, `.env.example`, or a
  custom name in any project (even one with no env files yet), optionally seeding keys
  from an existing file.
- **Pin & Finder** — pin projects to the top; right-click to Reveal / Open in Finder or
  copy the path. Per-file variable counts on the tabs.
- **Masking** — values are dots by default; reveal per-row (click the eye) or all at once.
  Safe to screen-share.
- **Inline validation** — non-blocking markers for duplicate keys, empty keys, and
  malformed lines (missing `=`, unbalanced quotes).
- **Environment tabs** — Development / Staging / Production / Other, driven by your own
  **editable, ordered regex rules** (first match wins).
- **Faithful save** — writes a `.bak` backup of the current file first, then rewrites the
  real file **preserving comments and blank lines**, keeping untouched lines byte-stable.
- **Scanner** — pick folders (remembered) and optionally deep-scan recursively. Runs
  off the main thread with progress and a **Cancel** button, honors an editable directory
  exclusion list (`node_modules`, `.git`, …), and auto-groups results into projects by
  parent folder.
- **Diff** — read-only side-by-side comparison of two environments: same / different /
  only-on-one-side.
- **Encrypted export / import** — `.envenc` files using **AES-256-GCM** with an **scrypt**
  key derivation. Export a single file or a whole project; import materializes the
  file(s) wherever you choose. Wrong passwords fail cleanly via the GCM auth tag.
- **CLI** — `scan`, `list`, `get`, `export`, `import` on the exact same core.

## Requirements

- **macOS 26 (Tahoe)** and **Xcode 26+** (Swift 6.x).
- EnvHub runs **without the App Sandbox** so it can read `.env` files across your home
  directory. macOS may prompt for **Full Disk Access** the first time you scan protected
  locations (Desktop / Documents / Downloads); grant it in
  *System Settings → Privacy & Security → Full Disk Access*.

## Architecture

One SwiftPM package (`EnvHubKit`) at the repo root holds all UI-free logic, the CLI, and
the tests. A thin SwiftUI app (`EnvHub/EnvHub.xcodeproj`) links it via a local package
reference (`../`) and consumes the `Core` and `Helper` products.

```
Package.swift                 EnvHubKit — libraries + CLI + tests
Sources/
  Model/        value types (Project, EnvFile, EnvVar, EnvKind, EnvDocument, rules,
                diff, export payloads) — depends on nothing
  Parser/       .env read/write, comment/blank-line preserving, validation      → Model
  Scanner/      cancellable filesystem discovery + glob matching + exclusions    → Model
  Classifier/   ordered regex rules → environment                               → Model
  Crypto/       AES-256-GCM + in-house scrypt (RFC 7914), .envenc envelope       → Model
  Core/         facade + services + SwiftData metadata (the app + CLI surface)
  Helper/       SwiftUI @Environment injection of Core services (UI glue only)   → Core
  envhub/       CLI executable                                                   → Core
Tests/          unit tests per module (UI-free): 47 tests
EnvHub/         SwiftUI macOS app (links Core + Helper)
```

Design principles:

- **Concern modules depend only on `Model`.** `Core` is the single facade both the app
  and CLI consume. `Helper` is the only package target that imports SwiftUI, so the CLI
  never links a UI framework.
- **`.env` files are the source of truth for values.** SwiftData stores only app state
  (projects, scan folders, exclusions, classification rules, preferences).
- **Dependency-injection** uses custom `EnvironmentKey`s (in `Helper`) that vend Core's
  stateless services into SwiftUI; the app injects them once at its root.
- **Crypto is dependency-free and auditable** — scrypt is implemented in-house on
  CryptoKit's HMAC/AES primitives and validated against the official RFC 7914 test
  vectors; AES-256-GCM comes from CryptoKit.

## Build & run

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
```

### Tests (UI-free, fast)

```sh
swift test
```

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
```

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

## Project status

Built in ten milestones (package skeleton → Model/Parser → app shell → editor → classifier
+ tabs → scanner → diff → crypto → CLI → polish). All ship with unit tests.

## Phase 2 (not built — clean seams left)

- **Cloud-provider import** (Vercel / Netlify / Railway / Fly): pull env vars straight
  from a provider into a local file using your own credentials, nothing routed through a
  server. The `EnvExport` / import layer is designed to accept a provider *source* without
  a rewrite.

## License

TBD.
