#!/bin/sh
# Builds build/Atrium-<version>.dmg: the app beside a link to Applications, for people who'd rather not build it.
# It's signed ad hoc, not notarised (that needs a paid Apple Developer ID), so macOS stops it the first time it's
# opened; README.md → Build from source says how to let it through.
set -e
cd "$(dirname "$0")"
./build.sh

PLIST=build/Atrium.app/Contents/Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$PLIST")
PRE=$(/usr/libexec/PlistBuddy -c 'Print AtriumPrerelease' "$PLIST" | tr -d ' ') # "rc 1" → "rc1"
DMG="build/Atrium-$VERSION${PRE:+-$PRE}.dmg"

STAGE=build/dmg
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R build/Atrium.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "Atrium" -srcfolder "$STAGE" -ov -format ULFO "$DMG"
rm -rf "$STAGE"
echo "Built $DMG ($(du -h "$DMG" | cut -f1))"
