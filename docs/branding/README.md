# Branding assets

Source for EnvHub's visual identity. Both are self-contained HTML rendered to PNG with
headless Chrome.

## App icon (`icon.html` → 1024×1024)

```sh
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
"$CHROME" --headless=new --disable-gpu --force-device-scale-factor=1 \
  --default-background-color=00000000 --screenshot=icon-1024.png \
  --window-size=1024,1024 "file://$PWD/icon.html"

# then generate the macOS icon set (16–1024) with sips into
# EnvHub/EnvHub/Assets.xcassets/AppIcon.appiconset/
for sz in 16 32 64 128 256 512; do sips -z $sz $sz icon-1024.png --out icon_${sz}.png; done
```

## README header (`header.html` → 2400×680 @2x)

```sh
"$CHROME" --headless=new --disable-gpu --force-device-scale-factor=2 \
  --screenshot=header.png --window-size=1200,340 "file://$PWD/header.html"
```
