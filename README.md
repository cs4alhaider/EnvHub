<p align="center">
  <img src="docs/screenshots/header.png" alt="EnvHub — every .env file on your machine, in one window" width="100%">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-26%20Tahoe-black?logo=apple&logoColor=white" alt="macOS 26">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/SwiftUI-native-2F6BF0" alt="SwiftUI">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-green" alt="GPL-3.0"></a>
  <img src="https://img.shields.io/badge/telemetry-none-brightgreen" alt="No telemetry">
</p>

<p align="center">
  Every <code>.env</code> file on your Mac. One home.<br>
  <b>Open source · local-only · no accounts · no telemetry.</b>
</p>

<p align="center">
  <a href="https://apps.apple.com/app/id6788664509">
    <img src="docs/branding/mac-app-store-badge.svg" alt="Download on the Mac App Store" height="56">
  </a>
  <br>
  <sub>Currently in App Review — releasing soon. The CLI is on Homebrew today.</sub>
</p>

---

<p align="center">
  <img src="docs/screenshots/editor.png" alt="EnvHub main window: workspace sidebar, environment tabs, and the structured editor" width="90%">
</p>

Your `.env` files are scattered across dozens of projects and hold your most sensitive
secrets. EnvHub gathers them into a single, native window — and because it reads
secrets, it's **open source on purpose**: verify yourself that nothing ever leaves
your Mac.

## Features

- **📁 Projects & workspaces** — pin, drag-and-drop, per-workspace dashboards, native tabs & windows.
- **✏️ A real editor** — Key / Value / **Comment** table (comments survive every save) plus a raw text mode.
- **🙈 Masked by default** — values show as dots until you reveal them; safe to screen-share.
- **🧾 Save review** — see added / changed / removed *before* anything touches disk, with an automatic `.bak` every save.
- **🧯 Faithful saves** — untouched lines are rewritten **byte-for-byte**; ordering, blank lines and comments preserved.
- **🏷️ Custom environments** — your names, colors and order, driven by editable filename rules.
- **🔎 Search everything** — **⇧⌘O** Quick Open across every project's keys, values, comments and filenames.
- **🔐 Encrypted sharing** — export a file, project or your whole library as a password-protected `.envenc` (scrypt + AES-256-GCM).
- **⚡ Fast scanner** — parallel, cache-skipping discovery of every `.env` in the folders you choose.
- **↔️ Diff** — side-by-side comparison of two environments.
- **⌨️ CLI** — the same core in your shell, sharing the same library ([reference](docs/CLI.md)).

## Install

**The app** — Mac App Store only:

<a href="https://apps.apple.com/app/id6788664509">
  <img src="docs/branding/mac-app-store-badge.svg" alt="Download on the Mac App Store" height="52">
</a>

**The CLI** — Homebrew:

```sh
brew install cs4alhaider/tap/envhub
```

Requires macOS 26 (Tahoe). Building from source? See [CONTRIBUTING.md](CONTRIBUTING.md).

## Screenshots

<table>
  <tr>
    <td width="50%" align="center">
      <img src="docs/screenshots/dashboard.png" alt="Workspace dashboard" width="100%"><br>
      <sub><b>Workspace dashboard</b> — click a section header for an overview of its projects.</sub>
    </td>
    <td width="50%" align="center">
      <img src="docs/screenshots/quick-open.png" alt="Quick Open search" width="100%"><br>
      <sub><b>Quick Open (⇧⌘O)</b> — search keys, values, and files across every project.</sub>
    </td>
  </tr>
  <tr>
    <td width="50%" align="center">
      <img src="docs/screenshots/environments.png" alt="Custom environments editor" width="86%"><br>
      <sub><b>Custom environments</b> — name, color, and safe-to-commit, per environment.</sub>
    </td>
    <td width="50%" align="center">
      <img src="docs/screenshots/onboarding.png" alt="Onboarding" width="100%"><br>
      <sub><b>Welcome</b> — a quick tour on first launch.</sub>
    </td>
  </tr>
</table>

## Documentation

| | |
| --- | --- |
| [docs/CLI.md](docs/CLI.md) | Every `envhub` command, the shared store, the AI-agent skill |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Package layout, design principles, how saving works |
| [docs/SECURITY.md](docs/SECURITY.md) | The `.envenc` format, crypto details, reporting vulnerabilities |
| [docs/SHORTCUTS.md](docs/SHORTCUTS.md) | Keyboard shortcuts |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Build from source + contribution guide |
| [PRIVACY.md](PRIVACY.md) | Privacy policy (spoiler: nothing is collected) |

## Author

Built by **Abdullah Alhaider** —
[alhaider.net](https://alhaider.net) ·
[GitHub @cs4alhaider](https://github.com/cs4alhaider) ·
[X @cs4alhaider](https://x.com/cs4alhaider)

If EnvHub is useful to you, a ⭐ helps others find it.

## License

[GPL-3.0](LICENSE) © Abdullah Alhaider. Official binaries on the Mac App Store are
additionally offered under Apple's standard EULA.
