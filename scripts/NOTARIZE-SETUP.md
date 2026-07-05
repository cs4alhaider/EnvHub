# One-time signing & notarization setup

`scripts/release.sh` needs two things from your Apple Developer account. Both are set up
once and reused for every release. This uses only Xcode / `xcrun` — no `asc`.

## 1. Developer ID Application certificate

Homebrew/direct distribution requires a **Developer ID Application** certificate (App
Store / Development certs won't work). Your team must be an **Organization** or
**Individual** enrolled account, and you must be the **Account Holder / Admin**.

Easiest, via Xcode:

1. **Xcode → Settings → Accounts**, select your Apple ID, pick the right team.
2. **Manage Certificates… → + (bottom-left) → Developer ID Application**.
3. It appears in your login keychain. Confirm:
   ```sh
   security find-identity -v -p codesigning | grep "Developer ID Application"
   ```

> The release script **auto-detects the team from your Developer ID certificate**, so
> whichever team you create the cert under is the one EnvHub ships under — you don't
> need to match the project's `DEVELOPMENT_TEAM`. (Override with `TEAM_ID=…` only if you
> hold Developer ID certs for more than one team.)

## 2. Notary credentials (a keychain profile)

`notarytool` authenticates with a stored keychain profile. Two ways to make one:

**A) App-specific password** (simplest)
1. Create one at <https://account.apple.com> → Sign-In & Security → App-Specific Passwords.
2. Store it:
   ```sh
   xcrun notarytool store-credentials envhub-notary \
     --apple-id "you@example.com" --team-id "G69L3HCQBT" --password "abcd-efgh-ijkl-mnop"
   ```

**B) App Store Connect API key** (better for CI)
1. App Store Connect → Users and Access → Integrations → App Store Connect API → generate
   a key (Developer role is enough), download the `.p8`.
2. Store it:
   ```sh
   xcrun notarytool store-credentials envhub-notary \
     --key "AuthKey_XXXX.p8" --key-id "XXXXXXXXXX" --issuer "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
   ```

## 3. Cut the release

```sh
# from the repo root — override TEAM_ID / SIGN_IDENTITY / NOTARY_PROFILE if needed
./scripts/release.sh
```

This produces `dist/EnvHub-<version>.zip` (notarized app, CLI bundled inside) and
`dist/envhub-<version>-macos.zip` (notarized CLI), and prints their SHA256s.

## 4. Publish

1. Tag + release (if not already): `git tag v<version> && git push origin v<version>` then
   `gh release create v<version> --generate-notes`.
2. Upload both zips:
   `gh release upload v<version> dist/EnvHub-<version>.zip dist/envhub-<version>-macos.zip`
3. In **cs4alhaider/homebrew-tap**, update `Casks/envhub-app.rb` and `Formula/envhub.rb`
   with the new `version` + `sha256`, and push.

Users then install with:
```sh
brew install --cask cs4alhaider/tap/envhub-app   # app + bundled CLI (symlinked)
brew install cs4alhaider/tap/envhub              # CLI only
```
