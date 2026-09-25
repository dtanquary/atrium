#!/bin/sh
# Builds build/Wallpaper.app, a menu-bar-only app. Run it with: open build/Wallpaper.app
set -e
cd "$(dirname "$0")"

swift build -c release

APP=build/Wallpaper.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Wallpaper "$APP/Contents/MacOS/"
cp -R Sources/Wallpaper/Resources/ "$APP/Contents/Resources/"
rm -f "$APP/Contents/Resources/.gitkeep"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Wallpaper</string>
    <key>CFBundleIdentifier</key><string>com.dtanquary.wallpaper</string>
    <key>CFBundleName</key><string>Wallpaper</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSUIElement</key><true/>
    <key>NSLocationUsageDescription</key><string>The Night Sky, Earth and Weather wallpapers show the sky and weather where you are.</string>
    <key>NSLocationWhenInUseUsageDescription</key><string>The Night Sky, Earth and Weather wallpapers show the sky and weather where you are.</string>
</dict>
</plist>
EOF
codesign --force --sign - "$APP"

echo "Built $APP"
