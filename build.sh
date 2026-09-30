#!/bin/sh
# Builds build/Atrium.app, a menu-bar-only app. Run it with: open build/Atrium.app
set -e
VERSION=0.67.0 # semantic versioning; see "Versioning" in CLAUDE.md
PRERELEASE= # e.g. "rc 1" while a release candidate: shown in Settings → About; VERSION stays three numbers, as macOS requires
cd "$(dirname "$0")"

# SwiftPM stamps the binary with the deployment target as its SDK, and macOS only gives apps built against its own
# SDK its current look (Liquid Glass), so stamp the real one.
swift build -c release -Xlinker -platform_version -Xlinker macos -Xlinker 26.0 -Xlinker "$(xcrun --show-sdk-version)"
BUILD=$(git rev-list --count HEAD 2>/dev/null || echo 0)

LOCATION="Wallpapers like Live Sky, Weather, Wind and Dappled Light show the real sky, weather and light where you are. Without your location, Atrium guesses from your time zone."
APP=build/Atrium.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Atrium "$APP/Contents/MacOS/"
cp -R Sources/Atrium/Resources/ "$APP/Contents/Resources/"
rm -f "$APP/Contents/Resources/.gitkeep"
cp LICENSE NOTICE "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Atrium</string>
    <key>CFBundleIdentifier</key><string>com.dtanquary.atrium</string>
    <key>CFBundleName</key><string>Atrium</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD</string>
    <key>AtriumPrerelease</key><string>$PRERELEASE</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.entertainment</string>
    <key>NSHumanReadableCopyright</key><string>© 2026 Dave Tanquary. MIT License.</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSUIElement</key><true/>
    <key>NSLocationUsageDescription</key><string>$LOCATION</string>
    <key>NSLocationWhenInUseUsageDescription</key><string>$LOCATION</string>
</dict>
</plist>
EOF
codesign --force --sign - "$APP"

echo "Built $APP $VERSION ($BUILD)${PRERELEASE:+ $PRERELEASE}"
