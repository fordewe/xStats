#!/bin/bash

set -e

# Get script directory (project root)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="xStats"
BUNDLE_ID="com.xstats.menu"
VERSION="1.0.2"
BUILD_DIR=".build/arm64-apple-macosx/release"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
DMG_NAME="xStats-${VERSION}.dmg"
DMG_PATH="$SCRIPT_DIR/$DMG_NAME"
DMG_VOLUME_ICON="Sources/xStatsMenu/Resources/DMGVolumeIcon.icns"

echo "🔨 Building $APP_NAME for release..."

# Clean build
rm -rf .build

# Build release
swift build -c release

echo "📦 Creating app bundle..."

# Create app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILD_DIR/xStats" "$APP_BUNDLE/Contents/MacOS/"

# Copy Info.plist
cp "Sources/xStatsMenu/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Copy AppIcon.icns (from build bundle or source)
if [ -f "$BUILD_DIR/xStats_xStats.bundle/AppIcon.icns" ]; then
    cp "$BUILD_DIR/xStats_xStats.bundle/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
elif [ -f "Sources/xStatsMenu/Resources/AppIcon.icns" ]; then
    cp "Sources/xStatsMenu/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

# Copy Assets.xcassets (for runtime access if needed)
cp -R "Sources/xStatsMenu/Resources/Assets.xcassets" "$APP_BUNDLE/Contents/Resources/"

# Set executable permissions
chmod +x "$APP_BUNDLE/Contents/MacOS/xStats"

echo "✅ App bundle created at: $APP_BUNDLE"

# Verify icon is in place
if [ -f "$APP_BUNDLE/Contents/Resources/AppIcon.icns" ]; then
    echo "✅ Icon file installed"
    ICON_SIZE=$(ls -lh "$APP_BUNDLE/Contents/Resources/AppIcon.icns" | awk '{print $5}')
    echo "   Icon size: $ICON_SIZE"
else
    echo "⚠️  Warning: Icon file not found"
fi

# Create DMG
echo "💿 Creating DMG installer..."

# Remove old DMG if exists
rm -f "$DMG_PATH"

# Create temporary DMG directory
DMG_DIR="$SCRIPT_DIR/.build/dmg"
rm -rf "$DMG_DIR"
mkdir -p "$DMG_DIR"

# Copy app to DMG directory
cp -R "$APP_BUNDLE" "$DMG_DIR/"

# Clear extended attributes (quarantine flags) so users can install without Gatekeeper issues
echo "🔒 Clearing extended attributes..."
xattr -cr "$DMG_DIR/${APP_NAME}.app"

# Create Applications symlink
ln -s /Applications "$DMG_DIR/Applications"

# Create DMG (hdiutil) - simple version without custom volume icon
hdiutil create -volname "$APP_NAME" \
               -srcfolder "$DMG_DIR" \
               -ov \
               -format UDZO \
               -imagekey zlib-level=9 \
               -quiet \
               "$DMG_PATH"

# Cleanup
rm -rf "$DMG_DIR"

echo ""
echo "✅ DMG created at: $DMG_PATH"
echo ""
echo "📦 Build Summary:"
echo "   App Bundle: $APP_BUNDLE"
echo "   DMG File:   $DMG_PATH"
ls -lh "$DMG_PATH"
echo ""
echo "To install: Open $DMG_NAME and drag $APP_NAME to Applications"

# Optional: Try to add custom volume icon if possible
if [ -f "$DMG_VOLUME_ICON" ]; then
    echo ""
    echo "💡 Tip: To add custom volume icon to DMG, you can use:"
    echo "   1. Mount the DMG: open $DMG_NAME"
    echo "   2. Copy the icon: cp $DMG_VOLUME_ICON /Volumes/xStats\\ Menu/.VolumeIcon.icns"
    echo "   3. Set icon bit: SetFile -a C /Volumes/xStats\\ Menu"
    echo "   4. Unmount: diskutil eject /Volumes/xStats\\ Menu"
fi
