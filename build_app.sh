#!/bin/bash
# ─────────────────────────────────────────────────────────
#  Build AppCleanerMac.app bundle
# ─────────────────────────────────────────────────────────

set -e
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="AppCleanerMac"
APP_BUNDLE="$REPO_DIR/$APP_NAME.app"
BINARY="$REPO_DIR/.build/release/$APP_NAME"

echo "🔨 Building release binary…"
cd "$REPO_DIR"
swift build -c release 2>&1 | grep -v "^warning:"

echo "📦 Creating .app bundle…"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Icon
cp "$REPO_DIR/Sources/AppCleanerMac/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Write Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AppCleanerMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.brandskitstudio.AppCleanerMac.Full</string>
    <key>CFBundleName</key>
    <string>AppCleanerMac</string>
    <key>CFBundleDisplayName</key>
    <string>AppCleanerMac</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>NSHumanReadableCopyright</key>
    <string>© 2025 AppCleaner Mac. All rights reserved.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>AppCleaner needs to communicate with other apps to find their related files.</string>
    <key>NSSystemAdministrationUsageDescription</key>
    <string>AppCleaner needs permission to remove application files and caches.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>AppCleaner needs access to find related files on your desktop.</string>
    <key>NSDocumentsFolderUsageDescription</key>
    <string>AppCleaner needs access to find related files in your documents.</string>
    <key>NSDownloadsFolderUsageDescription</key>
    <string>AppCleaner needs access to find related files in your downloads.</string>
</dict>
</plist>
PLIST

echo "🔐 Signing app with entitlements…"
codesign --force --options runtime --entitlements "$REPO_DIR/AppCleanerMac.entitlements" -s - "$APP_BUNDLE"

echo "✅ Built: $APP_BUNDLE"
echo ""
echo "🚀 Launch with:"
echo "   open \"$APP_BUNDLE\""
echo ""
echo "Or copy to /Applications:"
echo "   cp -R \"$APP_BUNDLE\" /Applications/"
