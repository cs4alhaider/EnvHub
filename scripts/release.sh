#!/usr/bin/env bash
#
# release.sh — build, Developer-ID-sign, notarize, and staple EnvHub for distribution
# outside the App Store (Homebrew / direct download). Produces two artifacts in dist/:
#
#   EnvHub-<version>.zip          the notarized, stapled app (with the CLI bundled inside)
#   envhub-<version>-macos.zip    the notarized, stapled standalone CLI
#
# Uses only stock Xcode tooling (xcodebuild, codesign, notarytool, stapler) — no asc.
#
# Prerequisites (one-time — see scripts/NOTARIZE-SETUP.md):
#   1. A "Developer ID Application" certificate in your login keychain.
#   2. A notarytool keychain profile:
#        xcrun notarytool store-credentials envhub-notary \
#          --apple-id you@example.com --team-id <TEAM> --password <app-specific-password>
#      (or --key/--key-id/--issuer for an App Store Connect API key)
#
# Configure via environment (or edit the defaults):
#   SIGN_IDENTITY   codesign identity (default: "Developer ID Application")
#   TEAM_ID         Apple Developer team id (default: from the project)
#   NOTARY_PROFILE  notarytool keychain profile name (default: envhub-notary)
#
set -euo pipefail

# ---- Config ------------------------------------------------------------------
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/EnvHub/EnvHub.xcodeproj"
SCHEME="EnvHub"
APP_NAME="EnvHub"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-envhub-notary}"
VERSION="${VERSION:-$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ MARKETING_VERSION = /{print $2; exit}')}"
VERSION="${VERSION:-0.2.0}"

# ---- Preflight: the Developer ID cert and notary profile must exist ----------
# Find the installed Developer ID Application certificate line, e.g.
#   1) ABC…  "Developer ID Application: Name (TEAMID)"
DEVID_LINE="$(security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 || true)"
if [ -z "$DEVID_LINE" ]; then
  echo "✗ No 'Developer ID Application' certificate found in your keychain." >&2
  echo "  Create one in Xcode → Settings → Accounts → Manage Certificates → + →" >&2
  echo "  Developer ID Application. See scripts/NOTARIZE-SETUP.md." >&2
  exit 1
fi
# The team is the (TEAMID) at the end of the cert's common name — use it for signing
# and export, so whichever team your Developer ID cert belongs to is the one we ship
# under. Override with TEAM_ID=… if you have more than one.
TEAM_ID="${TEAM_ID:-$(sed -E 's/.*\(([A-Z0-9]{10})\)".*/\1/' <<<"$DEVID_LINE")}"
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "✗ No notarytool keychain profile named '$NOTARY_PROFILE'." >&2
  echo "  Create it with: xcrun notarytool store-credentials $NOTARY_PROFILE …" >&2
  echo "  See scripts/NOTARIZE-SETUP.md." >&2
  exit 1
fi

BUILD="$ROOT/build"
DIST="$ROOT/dist"
ARCHIVE="$BUILD/EnvHub.xcarchive"
EXPORT="$BUILD/export"
rm -rf "$BUILD" "$DIST"; mkdir -p "$BUILD" "$DIST"

echo "▸ EnvHub $VERSION  ·  team $TEAM_ID  ·  identity: $SIGN_IDENTITY"

# ---- 1. Build the CLI --------------------------------------------------------
echo "▸ Building the envhub CLI (release)…"
swift build -c release --product envhub --package-path "$ROOT"
CLI_BIN="$ROOT/.build/release/envhub"

# ---- 2. Archive the app ------------------------------------------------------
echo "▸ Archiving the app…"
xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE" archive \
  DEVELOPMENT_TEAM="$TEAM_ID" | tail -3

# ---- 3. Export with Developer ID ---------------------------------------------
cat > "$BUILD/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
echo "▸ Exporting (Developer ID)…"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$BUILD/ExportOptions.plist" -exportPath "$EXPORT" | tail -3
APP="$EXPORT/$APP_NAME.app"

# ---- 4. Embed the CLI in the app, then re-sign inside-out ---------------------
echo "▸ Embedding the CLI in the app bundle…"
mkdir -p "$APP/Contents/Helpers"
cp "$CLI_BIN" "$APP/Contents/Helpers/envhub"
codesign --force --options runtime --timestamp -s "$SIGN_IDENTITY" "$APP/Contents/Helpers/envhub"
# Re-seal the app so its signature covers the newly-added helper.
codesign --force --options runtime --timestamp -s "$SIGN_IDENTITY" "$APP"
codesign --verify --deep --strict "$APP" && echo "  ✓ app signature valid"

# ---- 5. Notarize + staple the app --------------------------------------------
echo "▸ Notarizing the app (this can take a few minutes)…"
ditto -c -k --keepParent "$APP" "$BUILD/EnvHub-notarize.zip"
xcrun notarytool submit "$BUILD/EnvHub-notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
ditto -c -k --keepParent "$APP" "$DIST/EnvHub-$VERSION.zip"
echo "  ✓ $DIST/EnvHub-$VERSION.zip"

# ---- 6. Sign + notarize the standalone CLI -----------------------------------
echo "▸ Signing + notarizing the standalone CLI…"
CLI_DIR="$BUILD/cli"; mkdir -p "$CLI_DIR"; cp "$CLI_BIN" "$CLI_DIR/envhub"
codesign --force --options runtime --timestamp -s "$SIGN_IDENTITY" "$CLI_DIR/envhub"
ditto -c -k "$CLI_DIR/envhub" "$BUILD/envhub-notarize.zip"
xcrun notarytool submit "$BUILD/envhub-notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
# CLI binaries can't be stapled (only bundles), but the notarization ticket is
# published, so Gatekeeper checks online. Ship the signed binary zipped.
ditto -c -k "$CLI_DIR/envhub" "$DIST/envhub-$VERSION-macos.zip"
echo "  ✓ $DIST/envhub-$VERSION-macos.zip"

# ---- 7. Hashes for the Homebrew formula/cask ---------------------------------
echo ""
echo "▸ SHA256 (paste into the tap):"
echo "  app  : $(shasum -a 256 "$DIST/EnvHub-$VERSION.zip" | awk '{print $1}')"
echo "  cli  : $(shasum -a 256 "$DIST/envhub-$VERSION-macos.zip" | awk '{print $1}')"
echo ""
echo "Next: upload both zips to the GitHub release, then update"
echo "  cs4alhaider/homebrew-tap  →  Casks/envhub-app.rb + Formula/envhub.rb"
