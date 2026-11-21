#!/bin/bash
# Build Release, sign it with the local self-signed identity, install it to /Applications and
# relaunch. The identity is created once with docs/signing.md; it keeps the Accessibility grant.
set -euo pipefail
cd "$(dirname "$0")/.." || exit 1

IDENTITY="Tinycast Self-Signed"
DERIVED=build/install
APP_NAME=Tinycast.app
DEST=/Applications/$APP_NAME

if [ -z "${DEVELOPER_DIR:-}" ] && ! xcode-select -p | grep -q '\.app/'; then
    echo "✗ xcode-select points at the Command Line Tools; set DEVELOPER_DIR to Xcode's." >&2
    exit 2
fi
if ! security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
    echo "✗ No \"$IDENTITY\" identity in the keychain. Create it with docs/signing.md." >&2
    exit 2
fi
command -v xcodegen >/dev/null && xcodegen generate --quiet

xcodebuild build -project Tinycast.xcodeproj -scheme Tinycast -configuration Release \
    -derivedDataPath "$DERIVED" CODE_SIGN_IDENTITY="$IDENTITY" -quiet

BUILT="$DERIVED/Build/Products/Release/$APP_NAME"
codesign --verify --deep --strict --verbose=2 "$BUILT"
signature=$(codesign -dvv "$BUILT" 2>&1)
grep -q "Authority=$IDENTITY" <<<"$signature" || {
    echo "✗ $BUILT is not signed by \"$IDENTITY\"." >&2
    exit 1
}

# Quit the running copy first, so the copy below never replaces a bundle that is executing.
osascript -e 'tell application id "com.xanderthunder.tinycast" to quit' 2>/dev/null || true
for _ in {1..50}; do
    pgrep -f "$DEST/Contents/MacOS/" >/dev/null || break
    sleep 0.1
done

rm -rf "$DEST"
ditto "$BUILT" "$DEST"
codesign --verify --deep --strict "$DEST"
open "$DEST"
echo "✓ Installed and launched $DEST"
