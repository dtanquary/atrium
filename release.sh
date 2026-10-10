#!/bin/sh
# Builds build/Atrium-<version>.dmg (Atrium-<version>-beta.dmg while build.sh has a PRERELEASE) for a GitHub release
# outside the App Store: signed with a Developer ID, notarized by Apple and stapled, so it opens without a Gatekeeper
# warning. Beside it, Atrium-<version>.files lists the app's files and where each sits in the image, which lets the
# app's updater fetch only the ones a copy lacks (docs/updates.md). A release attaches both.
# One-time setup on this Mac:
#   1. Xcode → Settings → Accounts → the team → Manage Certificates → + → Developer ID Application
#   2. xcrun notarytool store-credentials atrium-notary --apple-id <Apple ID> --team-id <team ID>
#      (it asks for an app-specific password, made at account.apple.com)
# Then ./release.sh, and publish the disk image and its list (see "Versioning" in CLAUDE.md). The list needs python3,
# which comes with Xcode's command line tools.
set -e
cd "$(dirname "$0")"
ID=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application: .*\)"/\1/p' | head -1)
[ -n "$ID" ] || { echo "No Developer ID Application certificate in the keychain: see the top of release.sh"; exit 1; }

./build.sh
APP=build/Atrium.app
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
PRE=$(/usr/libexec/PlistBuddy -c 'Print AtriumPrerelease' "$APP/Contents/Info.plist" | tr -d ' ') # "rc 1" → "rc1"
DMG=build/Atrium-$VERSION${PRE:+-$PRE}.dmg
FILES=${DMG%.dmg}.files

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
rm -rf build/dmg "$DMG" "$FILES"
mkdir build/dmg
ditto "$APP" build/dmg/Atrium.app
ln -s /Applications build/dmg/Applications
# Uncompressed (UDRO): the photos don't compress anyway (2% larger), and every file then sits in the image whole.
diskutil image create from --format UDRO --volumeName Atrium build/dmg "$DMG" >/dev/null
codesign --sign "$ID" --timestamp "$DMG"
# ponytail: only the disk image gets the stapled ticket; the app copied out of it is checked online on first
# launch. Notarize and staple the app before building the image if offline first launches matter.
xcrun notarytool submit "$DMG" --keychain-profile atrium-notary --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG"

# The list the updater works from, a line for each file: its SHA-256, size, where it starts in the finished image, its
# permissions (755 if it runs, else 644: the updater takes no others) and its path. Each file is found by its bytes, so
# a place in the list is a place it was read back from.
python3 - "$DMG" build/dmg/Atrium.app > "$FILES" <<'EOF' || { rm -f "$FILES"; exit 1; }
import hashlib, mmap, os, sys
image = mmap.mmap(os.open(sys.argv[1], os.O_RDONLY), 0, access=mmap.ACCESS_READ)
for folder, folders, names in sorted(os.walk(sys.argv[2])):
    for name in sorted(folders + names):
        path = os.path.join(folder, name)
        # ponytail: plain files only. A framework's links would need a kind of line of their own, and the updater to make them.
        if os.path.islink(path): sys.exit(f"{path} is a link, and the updater builds an app of plain files only")
        if name in folders: continue
        data = open(path, "rb").read()
        at = image.find(data)
        if at < 0: sys.exit(f"{path} isn't in the image in one piece, so no copy could update to this release file by file")
        print(hashlib.sha256(data).hexdigest(), len(data), at, 755 if os.stat(path).st_mode & 0o111 else 644, os.path.relpath(path, sys.argv[2]), sep="\t")
EOF
echo "Built $DMG and $FILES"
