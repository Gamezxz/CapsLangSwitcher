#!/bin/bash
# Make a Sparkle release end-to-end:
#   signed + notarized .zip + appcast item + GitHub release
#
# Usage: ./make_release.sh X.Y.Z ["one-line release notes"]
#   e.g. ./make_release.sh 1.1.0 "Faster switching, bug fixes"
#
# Prereqs:
#   - EdDSA keypair already generated (generate_keys, once). sign_update pulls
#     the private key from the macOS keychain automatically.
#   - notarytool credentials stored under profile "capslangswitcher-notary"
set -e
cd "$(dirname "$0")"

APP_NAME="CapsLangSwitcher"
APP_BUNDLE="$APP_NAME.app"
VERSION="${1:?usage: ./make_release.sh X.Y.Z [\"release notes\"]}"
NOTES="${2:-Bug fixes and improvements.}"
NOTARY_PROFILE="capslangswitcher-notary"

SIGN_UPDATE=$(find .build/artifacts -type f -name sign_update -path "*bin*" ! -path "*old_dsa_scripts*" 2>/dev/null | head -1)
if [ -z "$SIGN_UPDATE" ]; then
    echo "sign_update tool not found — run 'swift build' first (to resolve Sparkle)"
    exit 1
fi

# 1. bump version
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" Info.plist

# 2. build + sign (Developer ID, hardened runtime)
echo "Building + signing $APP_BUNDLE..."
./build_app.sh

# 3. notarize + staple the .app itself
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "No credentials profile '$NOTARY_PROFILE' — create it first:"
    echo "   xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id <apple-id> --team-id DYJAX3728R --password <app-specific-password>"
    exit 1
fi
echo "Notarizing $APP_BUNDLE (can take a few minutes)..."
NOTARY_ZIP="/tmp/${APP_NAME}-notary.zip"
rm -f "$NOTARY_ZIP"
ditto -c -k --keepParent "$APP_BUNDLE" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
rm -f "$NOTARY_ZIP"
xcrun stapler staple "$APP_BUNDLE"
echo "$APP_BUNDLE notarized + stapled"

# 4. zip the stapled .app for Sparkle
echo "Zipping $APP_BUNDLE for Sparkle..."
RELEASE_ZIP="${APP_NAME}-${VERSION}.zip"
rm -f "$RELEASE_ZIP"
ditto -c -k --keepParent "$APP_BUNDLE" "$RELEASE_ZIP"

# 4b. build a drag-to-Applications DMG from the stapled .app (for fresh installs)
echo "Building installer DMG..."
./make_dmg.sh
RELEASE_DMG="${APP_NAME}-${VERSION}.dmg"

# 5. EdDSA-sign the zip (private key from keychain)
echo "Signing update (EdDSA)..."
SIG_OUT=$("$SIGN_UPDATE" "$RELEASE_ZIP")
EDSIG=$(echo "$SIG_OUT" | grep -o 'edSignature="[^"]*"' | cut -d'"' -f2)
LENGTH=$(echo "$SIG_OUT" | grep -o 'length="[^"]*"' | cut -d'"' -f2)
if [ -z "$EDSIG" ] || [ -z "$LENGTH" ]; then
    echo "Failed to parse sign_update output:"; echo "$SIG_OUT"; exit 1
fi
echo "   edSignature: $EDSIG"
echo "   length: $LENGTH"

# 6. insert a new <item> at the top of the appcast
echo "Updating docs/appcast.xml..."
PUBDATE=$(LC_ALL=C date -R)
VERSION="$VERSION" PUBDATE="$PUBDATE" NOTES="$NOTES" EDSIG="$EDSIG" LENGTH="$LENGTH" APP_NAME="$APP_NAME" \
python3 - <<'PY'
import os
v, pub, notes, sig, length, app = (os.environ[k] for k in
    ("VERSION", "PUBDATE", "NOTES", "EDSIG", "LENGTH", "APP_NAME"))
item = f'''    <item>
        <title>Version {v}</title>
        <pubDate>{pub}</pubDate>
        <sparkle:version>{v}</sparkle:version>
        <sparkle:shortVersionString>{v}</sparkle:shortVersionString>
        <description><![CDATA[{notes}]]></description>
        <enclosure url="https://github.com/Gamezxz/CapsLangSwitcher/releases/download/v{v}/{app}-{v}.zip" type="application/octet-stream" sparkle:edSignature="{sig}" sparkle:length="{length}" />
    </item>'''
path = "docs/appcast.xml"
with open(path, encoding="utf-8") as f:
    txt = f.read()
marker = "<language>en</language>"
if marker not in txt:
    raise SystemExit("marker <language>en</language> not found in appcast.xml")
if f"<sparkle:version>{v}</sparkle:version>" in txt:
    raise SystemExit(f"version {v} already present in appcast.xml")
txt = txt.replace(marker, marker + "\n" + item, 1)
with open(path, "w", encoding="utf-8") as f:
    f.write(txt)
print(f"   inserted item for v{v}")
PY

# 7. GitHub release — DMG for fresh installs, zip for Sparkle auto-update
echo "Creating GitHub release v$VERSION..."
gh release create "v$VERSION" "$RELEASE_DMG" "$RELEASE_ZIP" \
    --title "$APP_NAME $VERSION" --notes "$NOTES"

cat <<EOF

Release v$VERSION created.

Still needs (by hand):
   git add Info.plist docs/appcast.xml
   git commit -m "Release v$VERSION"
   git push
   (GitHub Pages redeploys — Sparkle reads the appcast from there)
EOF
