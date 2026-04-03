#!/bin/bash
set -e

APP_NAME="OpenDisplay"
VERSION="1.0.0"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

echo "🔨 Building $APP_NAME v$VERSION..."

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build release binary (universal: arm64 + x86_64)
echo "  Building arm64..."
swift build -c release --arch arm64 2>&1 | tail -1

echo "  Building x86_64..."
swift build -c release --arch x86_64 2>&1 | tail -1

echo "  Creating universal binary..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

lipo -create \
    .build/arm64-apple-macosx/release/OpenDisplay \
    .build/x86_64-apple-macosx/release/OpenDisplay \
    -output "$APP_BUNDLE/Contents/MacOS/OpenDisplay"

# Copy Info.plist
cp Info.plist "$APP_BUNDLE/Contents/"

# Copy icon
if [ -f "OpenDisplay/AppIcon.icns" ]; then
    cp OpenDisplay/AppIcon.icns "$APP_BUNDLE/Contents/Resources/"
fi

# Copy entitlements
cp OpenDisplay/Entitlements.plist "$APP_BUNDLE/Contents/Resources/"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "📦 App bundle created: $APP_BUNDLE"

# Sign (ad-hoc if no identity available)
echo "🔏 Signing..."
if security find-identity -v -p codesigning 2>/dev/null | grep -q "Developer ID"; then
    IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID" | head -1 | awk -F'"' '{print $2}')
    codesign --force --deep --sign "$IDENTITY" \
        --entitlements OpenDisplay/Entitlements.plist \
        "$APP_BUNDLE"
    echo "  Signed with: $IDENTITY"
else
    codesign --force --deep --sign - \
        --entitlements OpenDisplay/Entitlements.plist \
        "$APP_BUNDLE"
    echo "  Signed ad-hoc (no Developer ID found)"
fi

# Create DMG
echo "💿 Creating DMG..."
DMG_NAME="$APP_NAME-$VERSION.dmg"
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$APP_BUNDLE" \
    -ov -format UDZO \
    "$BUILD_DIR/$DMG_NAME" 2>/dev/null

echo "📁 Creating ZIP..."
cd "$BUILD_DIR"
zip -r "$APP_NAME-$VERSION.zip" "$APP_NAME.app" > /dev/null
cd ..

echo ""
echo "✅ Done!"
echo "   App:  $APP_BUNDLE"
echo "   DMG:  $BUILD_DIR/$DMG_NAME"
echo "   ZIP:  $BUILD_DIR/$APP_NAME-$VERSION.zip"
echo ""
echo "To install: drag $APP_NAME.app to /Applications"
echo "To run:     open $APP_BUNDLE"
