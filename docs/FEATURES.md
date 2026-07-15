# EnvHub — Complete Feature Inventory

> **Purpose:** the single source of truth for the EnvHub website (landing page,
> documentation, support). Every feature and subfeature of the app + CLI, verified
> against the code on `app-store-prep` (v1.0.0, 2026-07-14). Build site copy from
> this file; don't re-derive features from memory.
>
> **Conventions**
> - `[MAS]` = App Store (sandboxed) edition · `[DevID]` = unsandboxed builds.
>   Untagged = both.
> - **2026-07-15 distribution decision: the app ships ONLY on the Mac App Store**
>   (id 6788664509; the Homebrew app cask is retired). `[DevID]` now means
>   "source-build only — NOT in any distributed app; do NOT feature on the
>   website." The CLI still ships via Homebrew.
> - `⌘…` = keyboard shortcut · `CLI:` = envhub command equivalent.
> - `shot:` = existing screenshot asset to reuse (`appstore-kit/raw/…`,
>   `docs/screenshots/…`) · `shot-needed:` = capture later for the zoomed section.

---

## 0. Positioning

- **One-liner:** Every `.env` file on your Mac. One home.
- **Subline:** Projects, workspaces and environments — organized in a fast, native macOS app.
- **Pillars (the landing page's 5 acts):**
  1. Organize — projects, workspaces, dashboards, tabs
  2. Edit safely — real editor, masked values, save review, backups
  3. Find instantly — Quick Open, cross-project search
  4. Share safely — encrypted `.envenc`, diff, example files
  5. Private by design — offline, open source, sandboxed
- **Audience:** developers with many projects; freelancers juggling client stacks;
  teams onboarding new machines; anyone who has grepped `~` for a lost API key.
- **Tone:** Apple-keynote confidence + developer honesty. No fear-mongering.

---

## 1. Projects & Workspaces

### 1.1 Add projects
- Add any folder as a project — `⌘N`, toolbar ⊕ menu, or Finder-style open panel.
- Works for folders **without** `.env` files too → lands on the create-file flow.
- Duplicate-proof: the same folder re-added (any spelling, symlink, trailing slash)
  is detected by canonical path and never duplicated.
- `[MAS]` the open panel grant doubles as the sandbox permission (see 12.3).
- CLI: `envhub add .` / `envhub add ~/code/my-app` (adds + brings the app forward).
- CLI: `envhub .` / `envhub <path>` opens a project **window** without adding it.

### 1.2 Sidebar & sections
- Sections: **Pinned**, your custom **workspaces**, **Others** — each with a live
  count badge. shot: `appstore-kit/raw/01-hero.png`
- Collapsible sections, remembered across launches; sections never collapse while
  a search is active (matches stay visible).
- Home-relative paths (`~/Developer/acme-api`) with head-truncation — the tail of
  the path is always visible; full path on hover.
- Pin/unpin any project; pinned projects surface at the top.

### 1.3 Workspaces
- Create (`⇧⌘N`), rename, delete (projects fall back to Others; disk untouched).
- Drag projects onto a section header to move them; multi-select for bulk
  move/remove (⌫ removes with confirmation).
- Sort a workspace's projects by name, path, or date added.
- CLI: `envhub workspace list | create | rename | delete | move | sort --by name`.

### 1.4 Workspace dashboard
- Click any section header → dashboard for that workspace: total projects, env
  files, variables; a card per project with file/variable counts and
  environment-colored dots. shot: `appstore-kit/raw/04-dashboard.png`
- Double-click a card (or context menu) → open that project in a window/tab.
- Zero extra I/O — stats come from the always-current search index.

### 1.5 Windows & tabs (navigate like Finder)
- **Native macOS tabs**: every tab is a full main window (sidebar + editor).
  Context menu "Open in New Tab(s)", or ⌘-double-click a sidebar row / dashboard
  card. Tab bar "+" opens another library tab; Merge All Windows works.
  shot: `appstore-kit/raw/05-tabs.png`
- **Standalone project windows**: double-click a sidebar row or dashboard card.
  Windows restore across launches.
- Multiple full main windows supported.

### 1.6 Project actions (toolbar)
- Project Actions menu: Reveal in Finder, Copy Path, add/remove the current file
  in `.gitignore` `[DevID]`.
- New File, Export (encrypted), Compare (diff) buttons — see 5, 6, 7.

---

## 2. The Editor

### 2.1 Structured table editing
- Key / Value / Comment table with inline editing; add (+) and delete (−) rows.
  shot: `appstore-kit/raw/01-hero.png`
- **Comments are first-class**: the `# comment` line directly above each entry is
  its Comment cell. Edit, add, or clear comments from the table; they survive
  every save. A blank line breaks the association (dotenv convention).
- Inline validation (duplicate keys and malformed lines are surfaced).
- Environment tabs across the top of each project: one tab per classified
  environment with entry counts and kind colors.

### 2.2 Masked values
- Values are **masked by default** (dot placeholders — safe to screen-share).
- Reveal per-row (eye button) or all at once (eye toggle in the editor bar);
  Settings → General → "Mask values by default" controls the default.
- Masking is app-wide: editor, Quick Open results, save review, diff, CLI.

### 2.3 Raw text mode
- Table ↔ Raw toggle: edit the file as plain text when you want to paste a whole
  block; raw edits are parsed back into the table.

### 2.4 Faithful saves (never mangle a file)
- Round-trip guarantee: untouched lines are **byte-identical** after save —
  ordering, blank lines, comments, even CRLF line endings are preserved.
- Every save writes a `.bak` backup next to the file first.
- Revert button discards unsaved changes.

### 2.5 Save review (see the diff before it hits disk)
- `⌘S` / Save opens a review sheet: **added / changed / removed** entries, value
  *and* comment changes, with masked values and an eye toggle.
  shot: `appstore-kit/raw/03-savereview.png`
- Formatting-only changes are called out ("no variable changes").
- The sheet reminds you: nothing is committed to git; the previous version is
  kept as `.bak`.
- Switching files with unsaved edits → Save & Switch / Discard / Cancel dialog.

### 2.6 File details popover
- ⓘ in the editor bar: created, modified, size, variable count, latest backup
  (name + date), read-only badge when applicable, Reveal in Finder.
  shot: `appstore-kit/raw/06-fileinfo.png`

### 2.7 Create files
- New File sheet: start blank, or **copy the keys of an existing file with all
  values stripped** — a perfect `.env.example` in one click (comments included).
- Pick the filename/environment; `[DevID]` optional "add to .gitignore" checkbox
  when the project is a git repo (defaults off for example files — they're meant
  to be committed).

---

## 3. Search

### 3.1 Sidebar search
- One field searches **project names, paths, filenames, keys, values, and
  comments** across every project; sidebar shows per-project hit-count badges.
- Powered by a precomputed index — no per-keystroke disk I/O, instant on
  hundreds of projects.

### 3.2 Quick Open (⇧⌘O)
- Xcode-style overlay: type anything, results grouped by project (project-name
  matches first, then variable hits), environment-colored dots, file labels.
  shot: `appstore-kit/raw/02-quickopen.png`
- Full keyboard flow: ↑/↓ to move, ↩ to jump straight to the project/file, Esc to
  dismiss. Menu: File → Search Across Projects…

### 3.3 Search privacy controls
- Settings → Search: per-environment toggles — e.g. **exclude Production values
  from search results entirely**. New/unknown environments are searchable by
  default (exclusion-based, so nothing silently disappears).

---

## 4. Environments & Classification

### 4.1 Built-in environments
- Development, Staging, Production, Local, Example, Other — each with a color
  used in tabs, dots, dashboards, and search results.

### 4.2 Custom environments
- Add your own (UAT, Pre-Prod, anything): custom title, color, and order.
  Names are slugified ("Pre Prod!" → `pre-prod`). Delete any except Other.
  shot: `appstore-kit/raw/07-environments.png`
- **Safe to commit** flag per environment: Example ships with it on — example/
  template files never trigger git warnings and default to committable.

### 4.3 Classification rules
- Ordered, editable regex rules map filenames → environments
  (`.env.production` → Production). First match wins; drag to reorder;
  enable/disable per rule; Reset to Defaults.
- Defaults handle the tricky cases: `example|sample|template` wins over
  environment names (`.env.production.example` = Example), `local` wins over its
  base (`.env.development.local` = Local).

---

## 5. Scanner (find what you already have)

- Scan any folder(s) for `.env*` files — `⇧⌘F`, toolbar, or onboarding.
- **Parallel** filesystem walk (bounded at up to 12 workers), typically a couple
  of seconds for a whole dev directory; progress with live counts.
- **Cancellable with partial results** — "Stop & Review" keeps what it found.
- Skips noise by default: `node_modules`, `.git`, build output, `~/Library`,
  package-manager caches… (fully editable exclusion list + filename patterns in
  Settings → Scanning; deep-scan default in Settings → General).
- Results grouped by folder with an **"Added" badge** for projects already in
  the library; Select All skips them; pick a destination workspace on import.
- `[MAS]` scanning covers folders you've granted; `[DevID]` scans anywhere
  (macOS may ask for Desktop/Documents/Downloads permission — that's macOS,
  not telemetry).
- CLI: `envhub scan ~/Developer --deep`.

---

## 6. Encrypted Sharing (.envenc)

### 6.1 Export
- Export **one file**, a **whole project**, or your **entire library** as a
  password-protected `.envenc` — toolbar Export button, or Settings → Data →
  "Export All Variables" for the library.
- Crypto: **scrypt** key derivation (RFC 7914, implemented in-house on Apple
  CryptoKit primitives, validated against the official test vectors) +
  **AES-256-GCM** authenticated encryption. No third-party crypto dependencies.
- Everything happens on-device; nothing is uploaded anywhere, ever.
- CLI: `envhub export ./my-app/.env --out secrets.envenc`,
  `envhub export ./my-app --project --password-file ./pw.txt`.

### 6.2 Import
- Import a `.envenc` (`⌘I`): preview what's inside, choose where files land;
  library exports recreate per-project subfolders (name clashes uniquified).
- Wrong password fails cleanly (authenticated encryption — no silent garbage).
- Round-trip is byte-faithful, comments included.
- CLI: `envhub import secrets.envenc --into ./restored --force`.

### 6.3 Use cases to feature
- Send a teammate the real config, password out-of-band.
- Move to a new Mac: one library export, one import.
- Encrypted off-site backup of every secret you have.

---

## 7. Diff (Compare Environments)

- Toolbar "Compare": **read-only side-by-side** of any two environments in a
  project — spot the key that exists in Development but is missing in
  Production *before* it bites. shot-needed: diff sheet (no launch hook; capture
  manually for the website's zoom section).

---

## 8. Git-leak Guard `[DevID]`

- When an open `.env` file is **tracked by git**, EnvHub shows a warning banner —
  your secrets are one push away from a leak.
- One-click remedy: **Unstage & Ignore** (`git rm --cached` + append to
  `.gitignore`); the working file stays on disk.
- Manual `.gitignore` management from the Project Actions menu (add/remove the
  current filename).
- Example-environment files are exempt (they're meant to be committed).
- Detection is batched (3 git spawns per project, not per file) — no lag.
- `[MAS]` note: the sandboxed edition can't spawn git, so the banner and
  git-based actions are Developer ID-only. **Do not advertise on MAS-specific
  pages.** (Plain-file `.gitignore` editing is planned to stay — see repo
  issue/REC 01 in appstore-kit.)

---

## 9. CLI (`envhub`)

- Own package (`EnvHubCLI/`), same Core as the app, **same shared store** — the
  workspaces you organize in the CLI appear in the app instantly.
- Commands:
  - `envhub add [path]` — add a folder as a project (persists, focuses app)
  - `envhub [path]` / `envhub open` — open a project window without adding
  - `envhub scan <dirs> [--deep]` — discover env files, grouped by folder
  - `envhub list <project> [--mask|--keys-only]` — files + variables
  - `envhub get KEY [--file f|--project p] [--mask]` — print one value
  - `envhub export <file|--project dir> [--out|--password-file]` — encrypt
  - `envhub import <envenc> [--into dir] [--force]` — decrypt/restore
  - `envhub workspace list|create|rename|delete|move|sort` — organize
  - `envhub store [--reveal]` — print/reveal the shared database path
- Masked output by default where values appear.
- Install: `brew install cs4alhaider/tap/envhub`; `[DevID]` app bundles the CLI
  (menu: Install Command Line Tool…). `ENVHUB_STORE=<path>` overrides the store.
- **Agent skill** ships in-repo (`skills/envhub-cli/`) — teaches AI coding agents
  safe usage (masking rules, password handling). Site: mention on docs page.

---

## 10. Onboarding & Help

- 5-page welcome flow on first launch: what EnvHub is → privacy model →
  workspaces → get-started actions (Add/Scan buttons wired in) → star/share.
  shot: `appstore-kit/raw/08-onboarding.png`
- Re-openable any time: Help → Welcome to EnvHub…
- Occasional, dismissible "Enjoying EnvHub?" star nudge (never during first run).
- Custom About window + Settings → About: version, author, links, why-open-source.
  shot: `docs/screenshots/about.png`

---

## 11. Settings (⌘,)

| Tab | Contents |
| --- | --- |
| General | Mask values by default · Deep scan by default |
| Classification | Rules editor (regex → environment) ⧸ Environments editor (add/rename/color/reorder/safe-to-commit) |
| Scanning | Filename patterns · excluded directories |
| Search | Per-environment searchability (exclusion-based) |
| Data | Library stats · store path + Reveal · Export All Variables (.envenc) · Remove All Projects · Reset EnvHub |
| About | Version, author, links, open-source rationale |

---

## 12. Privacy & Security (the trust page)

### 12.1 Offline by architecture
- No accounts, no backend, no telemetry, no crash reporting — the app makes
  **zero network requests** (verifiable in the open source).
- App Store privacy label: **Data Not Collected**. Privacy manifest ships in the
  bundle; policy at `PRIVACY.md`.

### 12.2 Your files stay yours
- `.env` files are edited **in place** — EnvHub's database stores only its own
  metadata (project paths, workspaces, settings), never your values.
- `.bak` safety copy before every save.
- Masked-by-default everywhere (editor, search, review, CLI).

### 12.3 Sandbox story
- `[MAS]` full App Sandbox: you grant folders through the standard macOS panel;
  access persists via security-scoped bookmarks; revoke any time (a clear
  "Grant Access" screen appears if macOS revokes).
- `[DevID]` unsandboxed so it can scan anywhere + spawn git; both editions share
  one code path with runtime gating.

### 12.4 Open source
- GPL-3.0, all code public: `github.com/cs4alhaider/EnvHub`. App Store binaries
  additionally under Apple's standard EULA.
- In-house, auditable crypto (scrypt on CryptoKit, RFC 7914 vectors in tests).

---

## 13. Engineering proof points (credibility strip / docs)

- Native SwiftUI on macOS 26 (Tahoe); Swift 6 strict concurrency (`@concurrent`
  services, MainActor views — no detached tasks).
- SwiftPM architecture: `EnvHubKit` (Model ← Parser/Scanner/Classifier/Crypto ←
  Core ← Helper) + thin app + `EnvHubCLI`. Business logic 100% in the package.
- 100 UI-free tests (Swift Testing), incl. parser round-trip byte-stability and
  RFC 7914 scrypt vectors.
- Fast: parallel scanner (~seconds for a whole dev dir), precomputed search
  index (zero I/O per keystroke), batched git status (3 spawns/project).
- One dependency total (swift-argument-parser, CLI only).

---

## 14. Keyboard shortcuts (docs page table)

| Action | Shortcut |
| --- | --- |
| Add Project… | ⌘N |
| New Workspace… | ⇧⌘N |
| Scan for .env Files… | ⇧⌘F |
| Import .envenc… | ⌘I |
| Search Across Projects (Quick Open) | ⇧⌘O |
| Save (opens Save Review) | ⌘S |
| Settings | ⌘, |
| Remove selected project(s) | ⌫ |
| New tab / window | native macOS tab & window shortcuts |

---

## 15. Distribution (download section)

| What | Where | Price |
| --- | --- | --- |
| **The app** | **Mac App Store only** — https://apps.apple.com/app/id6788664509 | Free |
| **The CLI** | Homebrew: `brew install cs4alhaider/tap/envhub` (or build from source) | Free |

- The app and CLI share one library (App Group container) — installing both just works.
- The Homebrew **app cask is retired** (2026-07-15); the Developer ID release
  pipeline was removed from the repo.
- Git-leak guard and the bundled-CLI installer exist only in unsandboxed source
  builds → **not part of the product story on the website**.

---

## 16. Website requirements (decisions captured)

- **Stack:** Vite + React. TypeScript. No heavy UI framework — hand-rolled
  components matching the brand system.
- **Themes:** **dark AND light, both first-class** (user requirement
  2026-07-14) — theme toggle + `prefers-color-scheme` default; brand
  blue→indigo gradient + the six environment-kind colors as accents in both.
- **Animation:** scroll-driven storytelling (IntersectionObserver/Framer
  Motion): staggered reveals, zoomed feature close-ups (crop into the raw
  screenshots — e.g. the masked-value column, the diff rows, the Quick Open
  panel), parallax glows, animated `KEY=•••` mono ticker motifs.
- **Pages:** ① Landing ② Documentation (how to do anything — task-oriented,
  from this inventory) ③ Support (FAQ, contact via GitHub issues, privacy
  policy link, App Store/review links).
- **Typography:** Apple system stack (SF Pro / SF Mono like the kit + frames).
- **Assets available now:** icon set (`EnvHub/EnvHub/Assets.xcassets/…`,
  1024px master), README banner art (`docs/branding/header.html`), 8 raw app
  captures (`appstore-kit/raw/`), 8 framed App Store shots
  (`appstore-kit/screenshots/`), README shots (`docs/screenshots/`).
- **Assets to capture for zoom sections:** diff sheet (7), scan sheet (5),
  export sheet (6.1), git banner `[DevID]` (8), light-mode variants of hero
  shots (the site's light theme should show a light-mode app window).
- **Honesty rule (updated 2026-07-15):** the website describes the Mac App
  Store app + the Homebrew CLI, nothing else — git-guard and the bundled-CLI
  installer are source-build extras and stay OFF the site entirely.
- **Proposed landing structure:** hero (icon + tagline + App Store badge +
  hero shot) → credibility strip → 5 pillar acts (each: big claim, zoomed
  screenshot crops, subfeature bullets) → CLI section (terminal animation) →
  privacy/trust panel → download CTA (App Store badge + brew one-liner) → footer.

---

*Generated 2026-07-14 from branch `app-store-prep` @ v1.0.0 — keep in sync with
CONTRIBUTING.md and README.md when features change.*
