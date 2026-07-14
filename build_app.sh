#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="CapsLangSwitcher"
APP_DIR="$APP_NAME.app"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"

echo "Building release..."
swift build -c release

echo "Assembling $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp ".build/release/$APP_NAME" "$APP_DIR/Contents/MacOS/$APP_NAME"
cp "Info.plist" "$APP_DIR/Contents/Info.plist"
cp "assets/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

# Embed Sparkle.framework (universal) for auto-update
SPARKLE_FW=$(find .build/artifacts -type d -name "Sparkle.framework" -path "*macos-arm64_x86_64*" 2>/dev/null | head -1)
if [ -n "$SPARKLE_FW" ]; then
  mkdir -p "$APP_DIR/Contents/Frameworks"
  rm -rf "$APP_DIR/Contents/Frameworks/Sparkle.framework"
  cp -R "$SPARKLE_FW" "$APP_DIR/Contents/Frameworks/Sparkle.framework"
  install_name_tool -add_rpath @loader_path/../Frameworks "$APP_DIR/Contents/MacOS/$APP_NAME" 2>/dev/null || true
  echo "Embedded Sparkle.framework"
else
  echo "Warning: Sparkle.framework not found — run 'swift build' first to resolve it"
fi

DEVELOPER_ID="Developer ID Application: Viriya Langkaviket (DYJAX3728R)"

if security find-identity -v -p codesigning "$KEYCHAIN" | grep -q "$DEVELOPER_ID"; then
  echo "Signing with $DEVELOPER_ID (hardened runtime, for notarization)"
  # Nested Sparkle.framework must be signed before the outer bundle — it has its own
  # nested executables (Autoupdate, XPC services) that each need hardened runtime +
  # a secure timestamp, or notarization rejects the whole thing.
  if [ -d "$APP_DIR/Contents/Frameworks/Sparkle.framework" ]; then
    codesign --force --deep --sign "$DEVELOPER_ID" --options runtime --timestamp \
      "$APP_DIR/Contents/Frameworks/Sparkle.framework"
  fi
  codesign --force --options runtime --timestamp \
    --entitlements "$APP_NAME.entitlements" \
    --sign "$DEVELOPER_ID" "$APP_DIR"
else
  echo "No Developer ID identity found — falling back to ad-hoc signing"
  # Ad-hoc sign with a stable identifier so re-signing the same bundle id keeps a consistent
  # TCC identity as much as ad-hoc signing allows (still may require re-approving Accessibility
  # after rebuilds — see README notes).
  codesign --force --deep --sign - --identifier "com.local.capslangswitcher" "$APP_DIR"
fi

echo "Built $APP_DIR"
