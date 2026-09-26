#!/bin/sh
# Builds build/Atrium.app, a menu-bar-only app. Run it with: open build/Atrium.app
set -e
VERSION=0.9.1 # semantic versioning; see "Versioning" in CLAUDE.md
cd "$(dirname "$0")"

swift build -c release

APP=build/Atrium.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Atrium "$APP/Contents/MacOS/"
cp -R Sources/Atrium/Resources/ "$APP/Contents/Resources/"
rm -f "$APP/Contents/Resources/.gitkeep"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Atrium</string>
    <key>CFBundleIdentifier</key><string>com.dtanquary.atrium</string>
    <key>CFBundleName</key><string>Atrium</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSUIElement</key><true/>
    <key>NSLocationUsageDescription</key><string>The Live Sky, Earth and Weather wallpapers show the sky and weather where you are.</string>
    <key>NSLocationWhenInUseUsageDescription</key><string>The Live Sky, Earth and Weather wallpapers show the sky and weather where you are.</string>
</dict>
</plist>
EOF
codesign --force --sign - "$APP"

echo "Built $APP $VERSION"
