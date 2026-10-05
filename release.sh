#!/bin/sh
# Builds build/Atrium-<version>.dmg (Atrium-<version>-beta.dmg while build.sh has a PRERELEASE) for a GitHub release
# outside the App Store: signed with a Developer ID, notarized by Apple and stapled, so it opens without a Gatekeeper
# warning.
# One-time setup on this Mac:
#   1. Xcode → Settings → Accounts → the team → Manage Certificates → + → Developer ID Application
#   2. xcrun notarytool store-credentials atrium-notary --apple-id <Apple ID> --team-id <team ID>
#      (it asks for an app-specific password, made at account.apple.com)
# Then ./release.sh, and publish the disk image (see "Versioning" in CLAUDE.md).
set -e
cd "$(dirname "$0")"
ID=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)
[ -n "$ID" ] || { echo "No Developer ID Application certificate in the keychain: see the top of release.sh"; exit 1; }

./build.sh
APP=build/Atrium.app
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
PRE=$(/usr/libexec/PlistBuddy -c 'Print AtriumPrerelease' "$APP/Contents/Info.plist" | tr -d ' ') # "rc 1" → "rc1"
DMG=build/Atrium-$VERSION${PRE:+-$PRE}.dmg

# Notarizing needs the hardened runtime, which keeps location from the app unless it's entitled to it.
cat > build/release.entitlements <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.personal-information.location</key><true/>
</dict>
</plist>
EOF
codesign --force --options runtime --timestamp --entitlements build/release.entitlements --sign "$ID" "$APP"

# The app beside a link to Applications, to drag it onto.
rm -rf build/dmg "$DMG"
mkdir build/dmg
ditto "$APP" build/dmg/Atrium.app
ln -s /Applications build/dmg/Applications
diskutil image create from --volumeName Atrium build/dmg "$DMG" >/dev/null
codesign --sign "$ID" --timestamp "$DMG"
# ponytail: only the disk image gets the stapled ticket; the app copied out of it is checked online on first
# launch. Notarize and staple the app before building the image if offline first launches matter.
xcrun notarytool submit "$DMG" --keychain-profile atrium-notary --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG"
echo "Built $DMG"
