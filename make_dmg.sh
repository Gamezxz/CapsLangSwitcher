#!/bin/bash
# Package the already-built + signed + notarized CapsLangSwitcher.app into a
# drag-to-Applications DMG, then sign + notarize + staple the DMG itself.
#
# Assumes CapsLangSwitcher.app already exists (run ./build_app.sh first) and,
# for a distributable DMG, that the .app is already notarized + stapled
# (make_release.sh does that before calling this).
#
# Usage: ./make_dmg.sh        (version taken from Info.plist)
set -e
cd "$(dirname "$0")"

APP_NAME="CapsLangSwitcher"
APP_BUNDLE="$APP_NAME.app"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
NOTARY_PROFILE="capslangswitcher-notary"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist 2>/dev/null || echo "1.0")
DMG_NAME="${APP_NAME}-${VERSION}.dmg"

[ -d "$APP_BUNDLE" ] || { echo "$APP_BUNDLE not found — run ./build_app.sh first"; exit 1; }

DEV_ID=$(security find-identity -v -p codesigning "$KEYCHAIN" 2>/dev/null | grep "Developer ID Application" | head -1 | sed -n 's/.*"\(.*\)".*/\1/p')

echo "Staging DMG contents..."
STAGE=$(mktemp -d)
cp -R "$APP_BUNDLE" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

RW_DMG="/tmp/${APP_NAME}-rw.dmg"
rm -f "$RW_DMG" "$DMG_NAME"

echo "Creating read-write DMG..."
hdiutil create -srcfolder "$STAGE" -fs HFS+ -volname "$APP_NAME" -format UDRW "$RW_DMG" >/dev/null

MOUNT_DIR="/tmp/${APP_NAME}_mnt"
rm -rf "$MOUNT_DIR"; mkdir -p "$MOUNT_DIR"
hdiutil attach "$RW_DMG" -readwrite -nobrowse -mountpoint "$MOUNT_DIR" >/dev/null

echo "Laying out installer window..."
osascript <<APPLESCRIPT || echo "   (skipped layout — DMG still installs fine)"
tell application "Finder"
    tell disk "$APP_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 760, 460}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 100
        set position of item "$APP_BUNDLE" of container window to {150, 175}
        set position of item "Applications" of container window to {410, 175}
        close without saving
    end tell
end tell
APPLESCRIPT

hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1

echo "Compressing to read-only DMG..."
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME" >/dev/null
rm -f "$RW_DMG"; rm -rf "$STAGE"

if [ -n "$DEV_ID" ]; then
    codesign --sign "$DEV_ID" --timestamp "$DMG_NAME" && echo "Signed DMG with Developer ID"
fi

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "No credentials profile '$NOTARY_PROFILE' — DMG built but NOT notarized."
    echo "Create it with: xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id <id> --team-id DYJAX3728R --password <app-specific-password>"
    exit 0
fi

echo "Notarizing $DMG_NAME (can take a few minutes)..."
xcrun notarytool submit "$DMG_NAME" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_NAME"
echo "Done: $DMG_NAME notarized + stapled"
ls -lh "$DMG_NAME"
