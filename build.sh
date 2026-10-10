#!/bin/sh
# Builds build/Atrium.app, a menu-bar-only app. Run it with: open build/Atrium.app
# APP_STORE=1 ./build.sh builds the Mac App Store variant instead: no updater, and sandboxed (see docs/app-store.md).
set -e
VERSION=0.103.1 # semantic versioning; see "Versioning" in CLAUDE.md
PRERELEASE=beta # until 1.0, then e.g. "rc 1" while a release candidate: shown in Settings → About; VERSION stays three numbers, as macOS requires
cd "$(dirname "$0")"

# SwiftPM stamps the binary with the deployment target as its SDK, and macOS only gives apps built against its own
# SDK its current look (Liquid Glass), so stamp the real one.
swift build -c release ${APP_STORE:+-Xswiftc -DAPP_STORE} -Xlinker -platform_version -Xlinker macos -Xlinker 26.0 -Xlinker "$(xcrun --show-sdk-version)"
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
if [ -n "$APP_STORE" ]; then
    # The App Store's sandbox, with what Atrium needs through it: the network for live data, and location.
    cat > build/appstore.entitlements <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key><true/>
    <key>com.apple.security.network.client</key><true/>
    <key>com.apple.security.personal-information.location</key><true/>
</dict>
</plist>
EOF
    codesign --force --sign - --entitlements build/appstore.entitlements "$APP"
else
    codesign --force --sign - "$APP"
fi

echo "Built $APP $VERSION ($BUILD)${PRERELEASE:+ $PRERELEASE}${APP_STORE:+, for the App Store}"
