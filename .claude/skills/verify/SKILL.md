---
name: verify
description: Build, launch, and screenshot the EnvHub macOS app to verify UI changes end-to-end. Use after changing app code to capture evidence of the running app.
---

# Verify EnvHub (macOS app)

UI scripting (System Events / synthetic keystrokes) is Accessibility-blocked for the
shell on this machine — drive UI states with the app's `ENVHUB_*` launch hooks instead.

## Build + sign

```bash
xcodebuild -project EnvHub/EnvHub.xcodeproj -scheme EnvHub -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO
APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/EnvHub-*/Build/Products/Debug/EnvHub.app | head -1)
codesign --force --deep -s - "$APP"
```

`swift test` covers the package; it is NOT app verification.

## Isolated store (never touch the real library)

```bash
mkdir -p /private/tmp/envhub-verify-store
```

Point `ENVHUB_STORE` at a file inside that directory. (Legacy-store import and
file migration were removed 2026-07-13 — an isolated store now starts empty,
no pre-touch needed.)

## Launch + capture

Launched apps don't inherit shell env — use `launchctl setenv` + `open -n`, and
ALWAYS `launchctl unsetenv` every var afterwards (protects the user's real app).
Find your instance's PID by diffing `pgrep -x EnvHub` before/after `open -n`; the
user often has their own Xcode-run instance — **kill only your PID, never pkill**.

Window bounds via a CGWindowListCopyWindowInfo swift script filtered by your PID
(screen-recording permission is granted), then `screencapture -o -x -R "x,y,w,h"` —
region capture composites sheets/popovers; `-l <windowid>` misses them.

## Useful hooks

`ENVHUB_STORE=<path>` `ENVHUB_SKIP_ONBOARDING=1` `ENVHUB_ADD_PROJECT=<path>` (add+select)
`ENVHUB_SELECT_PROJECT=<path>` `ENVHUB_SHOW_FILE_INFO=1` (editor ⓘ popover)
`ENVHUB_SHOW_SAVE_REVIEW=1` (seeds demo edits, opens save-review sheet)
`ENVHUB_SHOW_SETTINGS=1` + `ENVHUB_SETTINGS_TAB=…` `ENVHUB_QUICK_OPEN=<query>`
`ENVHUB_SHOW_DASHBOARD=<name|others>` `ENVHUB_SHOW_ABOUT=1` `ENVHUB_COLLAPSE=ids`
`ENVHUB_OPEN_WINDOW=<path>` (project window) `ENVHUB_OPEN_TAB=<path[:path…]>` (native tabs on main window)

A reusable per-shot launcher lived at scratchpad `shot.sh` (session 2026-07-09) —
recreate: setenv vars → `open -n` → sleep 4 → pid diff → windowinfo → region capture
→ kill own pid → unsetenv extras.

Demo fixtures: create under `$HOME/.envhub-verify/...` for home-relative sidebar
paths; `/private/tmp/...` fixtures demo the outside-home absolute-path case.
