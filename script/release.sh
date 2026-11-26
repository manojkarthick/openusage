#!/usr/bin/env bash
set -euo pipefail

# Builds an arm64, ad-hoc signed OpenUsage.app (without iCloud) and wraps it in
# dist/OpenUsage-<version>.dmg. When SPARKLE_PUBLIC_KEY is set, bakes in the Sparkle feed keys so
# in-app auto-updates are active; otherwise leaves the updater dormant for local packaging runs.
#
# Required env:
#   OPENUSAGE_VERSION     human version, e.g. 0.7.17 (CFBundleShortVersionString)
# Optional env:
#   OPENUSAGE_BUILD       CFBundleVersion (monotonic). Default: git commit count.
#   SPARKLE_PUBLIC_KEY    base64 EdDSA public key (SUPublicEDKey). Enables Sparkle when set.
#   SPARKLE_FEED_URL      appcast URL. Default: https://manojkarthick.github.io/openusage/appcast.xml

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

: "${OPENUSAGE_VERSION:?set OPENUSAGE_VERSION, e.g. 0.7.17}"

APP_NAME="OpenUsage"
BUNDLE_ID="com.robinebers.openusage"
MIN_SYSTEM_VERSION="15.0"
VERSION="$OPENUSAGE_VERSION"
BUILD="${OPENUSAGE_BUILD:-$(git rev-list --count HEAD)}"
FEED_URL="${SPARKLE_FEED_URL:-https://manojkarthick.github.io/openusage/appcast.xml}"
SPARKLE_PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-}"
DMG_NAME="$APP_NAME-$VERSION.dmg"

DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_HELPERS="$APP_CONTENTS/Helpers"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
CLI_BINARY="$APP_HELPERS/openusage"
DMG_PATH="$DIST_DIR/$DMG_NAME"

echo "==> building $APP_NAME $VERSION ($BUILD) — arm64"
swift build -c release --arch arm64 --product OpenUsage
swift build -c release --arch arm64 --product openusage-cli
BUILD_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
BUILD_BINARY="$BUILD_DIR/$APP_NAME"
BUILD_CLI_BINARY="$BUILD_DIR/openusage-cli"
[ -x "$BUILD_BINARY" ] || { echo "missing built binary: $BUILD_BINARY" >&2; exit 1; }
[ -x "$BUILD_CLI_BINARY" ] || { echo "missing built CLI: $BUILD_CLI_BINARY" >&2; exit 1; }

echo "==> staging $APP_BUNDLE"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_HELPERS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$BUILD_CLI_BINARY" "$CLI_BINARY"
chmod +x "$APP_BINARY" "$CLI_BINARY"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$CLI_BINARY"

# SwiftPM stamps LC_BUILD_VERSION's sdk field with the deployment target (15.0), which makes AppKit
# fall back to legacy Aqua controls on Tahoe. Restamp sdk to 26.0 while keeping minos at 15.0.
echo "==> stamping linked SDK 26.0 for Liquid Glass controls (minos stays $MIN_SYSTEM_VERSION)"
vtool -set-build-version macos "$MIN_SYSTEM_VERSION" 26.0 -replace -output "$APP_BINARY.tmp" "$APP_BINARY"
mv "$APP_BINARY.tmp" "$APP_BINARY"
chmod +x "$APP_BINARY"

shopt -s nullglob
for bundle in "$BUILD_DIR"/*.bundle; do
  cp -R "$bundle" "$APP_RESOURCES/$(basename "$bundle")"
done
shopt -u nullglob

if [ -f "$ROOT_DIR/assets/AppIcon.prebuilt/Assets.car" ]; then
  echo "==> installing prebuilt app icon"
  cp "$ROOT_DIR/assets/AppIcon.prebuilt/Assets.car" "$APP_RESOURCES/Assets.car"
  [ -f "$ROOT_DIR/assets/AppIcon.prebuilt/AppIcon.icns" ] \
    && cp "$ROOT_DIR/assets/AppIcon.prebuilt/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
else
  echo "==> compiling app icon"
  xcrun actool "$ROOT_DIR/assets/AppIcon.icon" --compile "$APP_RESOURCES" \
    --app-icon AppIcon --enable-on-demand-resources NO --development-region en \
    --target-device mac --platform macosx --minimum-deployment-target "$MIN_SYSTEM_VERSION" \
    --output-partial-info-plist /dev/null --output-format human-readable-text --errors --warnings
fi

# Omit NSUbiquitousContainers so iCloud sync stays off. Only write Sparkle keys when a public EdDSA
# key is supplied (CI releases pass it; local packaging runs stay dormant by default).
SPARKLE_PLIST=""
if [ -n "$SPARKLE_PUBLIC_KEY" ]; then
  SPARKLE_PLIST=$(cat <<SPARKLE
  <key>SUFeedURL</key><string>$FEED_URL</string>
  <key>SUPublicEDKey</key><string>$SPARKLE_PUBLIC_KEY</string>
  <key>SUEnableAutomaticChecks</key><true/>
  <key>SUScheduledCheckInterval</key><integer>3600</integer>
SPARKLE
)
fi

cat >"$APP_CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$BUILD</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_SYSTEM_VERSION</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSUIElement</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
${SPARKLE_PLIST}
</dict>
</plist>
PLIST

"$ROOT_DIR/script/embed_sparkle.sh" "$APP_BUNDLE" "$APP_BINARY" "-"
codesign --force --sign - "$CLI_BINARY"

echo "==> signing app (ad-hoc)"
codesign --force --sign - "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "==> building $DMG_PATH"
STAGE="$(mktemp -d)"
cp -R "$APP_BUNDLE" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG_PATH" >/dev/null
rm -rf "$STAGE"

SHA="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"
echo "==> done"
echo "    DMG:    $DMG_PATH"
echo "    SHA256: $SHA"
