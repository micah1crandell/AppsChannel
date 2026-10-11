#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# AppsChannel Mac App Store Build & Package Tool
# Builds the sandboxed App Store target, eliminates Sparkle framework,
# signs with App Store entitlements, and generates a submission-ready .pkg.
# ==============================================================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SIGN_IDENTITY="${1:-}"
INSTALLER_SIGN_IDENTITY="${2:-}"
OUTPUT_DIR="${3:-$REPO_ROOT/build-appstore}"
ENTITLEMENTS="$REPO_ROOT/AppsChannel/AppsChannel.appstore.entitlements"
SCHEME="AppsChannel (App Store)"
CONFIG="AppStore"

echo "========================================================"
echo "🍎 AppsChannel - Mac App Store Packaging Pipeline"
echo "========================================================"
echo "Scheme:               $SCHEME"
echo "Configuration:        $CONFIG"
echo "App Sign Identity:    ${APP_SIGN_IDENTITY:-(Ad-hoc / Unsigned)}"
echo "Installer Identity:   ${INSTALLER_SIGN_IDENTITY:-(None)}"
echo "Output Directory:     $OUTPUT_DIR"
echo "Entitlements:         $ENTITLEMENTS"
echo "========================================================"

# Step 1: Clean and build the App Store scheme
mkdir -p "$OUTPUT_DIR"
echo "🔨 Building $SCHEME..."

BUILD_ARGS=(
    -project "$REPO_ROOT/AppsChannel.xcodeproj"
    -scheme "$SCHEME"
    -configuration "$CONFIG"
    -destination 'generic/platform=macOS'
    -derivedDataPath "$OUTPUT_DIR/DerivedData"
)

# If identity isn't specified, disable strict code signing during xcodebuild
if [ -z "$APP_SIGN_IDENTITY" ]; then
    BUILD_ARGS+=(
        CODE_SIGN_IDENTITY=""
        CODE_SIGNING_REQUIRED=NO
        CODE_SIGN_ENTITLEMENTS=""
    )
fi

xcodebuild "${BUILD_ARGS[@]}" build

APP_PATH="$OUTPUT_DIR/DerivedData/Build/Products/$CONFIG/AppsChannel.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Built application not found at: $APP_PATH"
    exit 1
fi

echo "✅ Build succeeded: $APP_PATH"

# Step 2: Strip Sparkle framework if present in App Store bundle
if [ -d "$APP_PATH/Contents/Frameworks/Sparkle.framework" ]; then
    echo "🧹 Removing Sparkle.framework from App Store bundle..."
    rm -rf "$APP_PATH/Contents/Frameworks/Sparkle.framework"
fi

# Remove Frameworks directory if it is now empty
if [ -d "$APP_PATH/Contents/Frameworks" ]; then
    if [ -z "$(ls -A "$APP_PATH/Contents/Frameworks" 2>/dev/null)" ]; then
        rm -rf "$APP_PATH/Contents/Frameworks"
    fi
fi

# Step 3: Sign embedded binaries and frameworks inside-out
echo "✍️  Signing bundle for Mac App Store..."
if [ -n "$APP_SIGN_IDENTITY" ] && [ "$APP_SIGN_IDENTITY" != "-" ]; then
    # Sign nested components if any exist
    if [ -d "$APP_PATH/Contents/Frameworks" ]; then
        find "$APP_PATH/Contents/Frameworks" -type d -name "*.framework" | while read -r fw; do
            codesign --force --verbose --options runtime --timestamp --sign "$APP_SIGN_IDENTITY" "$fw"
        done
    fi

    # Sign main application bundle with sandbox entitlements
    codesign --force --verbose --options runtime --timestamp \
        --entitlements "$ENTITLEMENTS" \
        --sign "$APP_SIGN_IDENTITY" \
        "$APP_PATH"
else
    echo "ℹ️  No Apple Distribution identity provided; performing ad-hoc sign for local verification..."
    codesign --force --verbose --options runtime \
        --entitlements "$ENTITLEMENTS" \
        --sign - \
        "$APP_PATH"
fi

# Step 4: Verify entitlements and sandbox status
echo "🔍 Validating embedded entitlements..."
codesign -d --entitlements - "$APP_PATH"

echo "🔍 Validating Sparkle linkage..."
if otool -L "$APP_PATH/Contents/MacOS/AppsChannel" | grep -qi "Sparkle"; then
    echo "❌ ERROR: Sparkle linkage detected in App Store binary!"
    exit 1
else
    echo "✅ Verified: Sparkle is completely absent from Mach-O linkage."
fi

# Step 5: Package into .pkg for App Store Connect submission
PKG_PATH="$OUTPUT_DIR/AppsChannel-AppStore.pkg"
echo "📦 Packaging component into: $PKG_PATH"
rm -f "$PKG_PATH"

PRODUCTBUILD_ARGS=(
    --component "$APP_PATH" /Applications
)

if [ -n "$INSTALLER_SIGN_IDENTITY" ]; then
    PRODUCTBUILD_ARGS+=(--sign "$INSTALLER_SIGN_IDENTITY")
fi

productbuild "${PRODUCTBUILD_ARGS[@]}" "$PKG_PATH"

echo "========================================================"
echo "🎉 App Store Package Created Successfully!"
echo "App Bundle: $APP_PATH"
echo "Package:    $PKG_PATH"
echo "========================================================"
echo "Next steps for App Store submission:"
echo "1. Sign with your Apple Distribution Certificate & 3rd Party Mac Developer Installer Certificate."
echo "2. Upload '$PKG_PATH' to App Store Connect using the 'Transporter' app or command line:"
echo "   xcrun altool --upload-app -f \"$PKG_PATH\" -t osx -u <AppleID> -p <AppSpecificPassword>"
echo "========================================================"
