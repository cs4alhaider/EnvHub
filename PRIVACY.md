# EnvHub Privacy Policy

**Effective date:** July 11, 2026

EnvHub is built on a simple rule: **your secrets never leave your Mac.**

## What EnvHub collects

Nothing.

EnvHub has no analytics, no telemetry, no crash reporting, no accounts, and no
servers. The app never makes a network request. The corresponding App Store
privacy label is **"Data Not Collected."**

## Where your data lives

- **Your `.env` files** stay exactly where they are on disk. EnvHub reads and
  writes them in place and keeps a local `.bak` backup next to the file when
  you save.
- **App state** (your project list, workspaces, pins, settings) is stored in a
  local database on your Mac. It contains file paths and app preferences — not
  the contents of your `.env` files.
- **Folder access** in the App Store edition is granted by you through the
  standard macOS open panel and remembered with security-scoped bookmarks,
  which stay on your Mac.

## Encrypted sharing

When you export an encrypted `.envenc` file, encryption happens locally on
your Mac (scrypt key derivation + AES-256-GCM). The file is yours; EnvHub
never uploads it anywhere. Anyone you share it with needs the passphrase you
chose.

## Third parties

There are none. EnvHub embeds no third-party SDKs, ad frameworks, or trackers.

## Open source

EnvHub's complete source code is public at
[github.com/cs4alhaider/EnvHub](https://github.com/cs4alhaider/EnvHub), so
every claim in this policy can be verified by reading the code.

## Changes

If this policy ever changes, the update will appear in this file with a new
effective date, alongside the app's release notes.

## Contact

Questions? Open an issue at
[github.com/cs4alhaider/EnvHub/issues](https://github.com/cs4alhaider/EnvHub/issues)
or reach the developer at [alhaider.net](https://alhaider.net).
