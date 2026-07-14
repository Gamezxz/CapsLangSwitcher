#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_DIR="CapsLangSwitcher.app"
ZIP="CapsLangSwitcher.app.zip"
PROFILE="capslangswitcher-notary"

rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP"

echo "Submitting for notarization (this can take a few minutes)..."
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

echo "Stapling ticket to app..."
xcrun stapler staple "$APP_DIR"

echo "Re-zipping stapled app..."
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP"

echo "Verifying Gatekeeper acceptance..."
spctl -a -vvv -t install "$APP_DIR"

echo "Done: $ZIP is notarized and stapled."
