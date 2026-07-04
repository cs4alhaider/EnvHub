# Homebrew distribution plan

Two installables, one tap:

```sh
brew tap cs4alhaider/tap
brew install envhub            # the CLI
brew install --cask envhub-app # the macOS app (once notarized releases exist)
```

## 1. Create the tap

A tap is just a repo named `homebrew-tap` under your account:

```
github.com/cs4alhaider/homebrew-tap
├── Formula/envhub.rb      ← template: docs/distribution/envhub.rb
└── Casks/envhub-app.rb    ← template: docs/distribution/envhub-app.rb
```

## 2. Release flow (per version)

1. Bump `Core.version`, tag `vX.Y.Z`, push the tag; create a GitHub Release.
2. **CLI artifact** (until CI does it):
   ```sh
   swift build -c release --product envhub
   codesign --sign "Developer ID Application: <NAME> (G69L3HCQBT)" \
            --options runtime --timestamp .build/release/envhub
   ditto -c -k .build/release/envhub envhub-X.Y.Z-macos-arm64.zip
   xcrun notarytool submit envhub-X.Y.Z-macos-arm64.zip \
         --keychain-profile envhub-notary --wait
   shasum -a 256 envhub-X.Y.Z-macos-arm64.zip
   gh release upload vX.Y.Z envhub-X.Y.Z-macos-arm64.zip
   ```
3. **App artifact**:
   ```sh
   xcodebuild -project EnvHub/EnvHub.xcodeproj -scheme EnvHub archive \
              -archivePath build/EnvHub.xcarchive
   xcodebuild -exportArchive -archivePath build/EnvHub.xcarchive \
              -exportOptionsPlist docs/distribution/ExportOptions.plist \
              -exportPath build/export        # method: developer-id
   ditto -c -k --keepParent build/export/EnvHub.app EnvHub-X.Y.Z.zip
   xcrun notarytool submit EnvHub-X.Y.Z.zip --keychain-profile envhub-notary --wait
   xcrun stapler staple build/export/EnvHub.app   # re-zip after stapling
   gh release upload vX.Y.Z EnvHub-X.Y.Z.zip
   ```
4. Update `url`/`sha256`/`version` in the tap's formula + cask, push the tap.

## 3. Formula strategy

- **Phase 1 — source build** (works today, no signing needed): the formula in
  `docs/distribution/envhub.rb` builds `--product envhub` from the tag tarball.
  Requires the user to have Xcode 26 (the package uses SwiftData/macOS 26 APIs).
- **Phase 2 — binary bottle** (preferred): once notarized CLI zips ship with each
  release, switch the formula to download the binary (commented variant included in
  the template). Instant installs, no Xcode requirement.
- **Phase 3 — automation**: a GitHub Actions `release.yml` on tag push runs tests,
  builds/signs/notarizes both artifacts (App Store Connect API key as secrets),
  uploads them, and opens a PR against the tap with the new sha256s.

## 4. Requirements & gotchas

- The app is **not sandboxed** (it must read `.env` files anywhere) → it can never
  ship in the Mac App Store, which makes Homebrew + GitHub Releases the primary
  channel. Notarization is still required so Gatekeeper allows it.
- `depends_on macos: :tahoe` on both — the codebase targets macOS 26 APIs.
- The CLI and app share the data store; keep them on the same version (see
  `CLI-PUBLISHING.md`).
- Submitting the cask to the official `homebrew/cask` needs 30+ GitHub stars and a
  notarized app; start in the personal tap and graduate later.
