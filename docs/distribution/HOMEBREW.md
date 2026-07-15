# Homebrew distribution (CLI only)

The **app ships exclusively on the Mac App Store**
(https://apps.apple.com/app/id6788664509). Homebrew distributes just the CLI:

```sh
brew tap cs4alhaider/tap
brew install envhub            # the CLI
```

## 1. The tap

A tap is just a repo named `homebrew-tap` under your account:

```
github.com/cs4alhaider/homebrew-tap
└── Formula/envhub.rb      ← template: docs/distribution/envhub.rb
```

(The old `Casks/envhub-app.rb` is retired — remove it from the tap; the app is
App Store-only.)

## 2. Release flow (per version)

1. Bump `Core.version`, tag `vX.Y.Z`, push the tag; create a GitHub Release.
2. **CLI artifact** (until CI does it):
   ```sh
   swift build -c release --product envhub --package-path EnvHubCLI
   codesign --sign "Developer ID Application: <NAME> (<TEAM>)" \
            --options runtime --timestamp EnvHubCLI/.build/release/envhub
   ditto -c -k EnvHubCLI/.build/release/envhub envhub-X.Y.Z-macos-arm64.zip
   xcrun notarytool submit envhub-X.Y.Z-macos-arm64.zip \
         --keychain-profile envhub-notary --wait
   shasum -a 256 envhub-X.Y.Z-macos-arm64.zip
   gh release upload vX.Y.Z envhub-X.Y.Z-macos-arm64.zip
   ```
3. Update `url`/`sha256`/`version` in the tap's formula, push the tap.
   ⚠️ From v1.0.0 the formula must build with `--package-path EnvHubCLI`
   (the CLI moved out of the root package) — the updated template is in
   `docs/distribution/envhub.rb`.

## 3. Formula strategy

- **Phase 1 — source build** (works today, no signing needed): the formula in
  `docs/distribution/envhub.rb` builds `--product envhub` from the tag tarball.
  Requires the user to have Xcode 26 (the package uses SwiftData/macOS 26 APIs).
- **Phase 2 — binary bottle** (preferred): once notarized CLI zips ship with each
  release, switch the formula to download the binary (commented variant included in
  the template). Instant installs, no Xcode requirement.
- **Phase 3 — automation**: a GitHub Actions `release.yml` on tag push runs tests,
  builds/signs/notarizes the CLI, uploads it, and opens a PR against the tap with
  the new sha256.

## 4. Requirements & gotchas

- **The app is Mac App Store-only** (sandboxed edition). Homebrew's job is the CLI.
- `depends_on macos: :tahoe` — the codebase targets macOS 26 APIs.
- The CLI and app share the data store (the `group.net.alhaider.EnvHub` container);
  keep them on the same version (see `CLI-PUBLISHING.md`).
