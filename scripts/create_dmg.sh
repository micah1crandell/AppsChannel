#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# AppsChannel DMG Builder
# Creates a polished, drag-and-drop macOS disk image (.dmg)
# ==============================================================================

APP_PATH="${1:-build/Build/Products/Release/AppsChannel.app}"
OUTPUT_DMG="${2:-build/Build/Products/Release/AppsChannel.dmg}"
VOLNAME="${3:-AppsChannel}"
ICON_PATH="AppsChannel/AppIcon.icns"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: App bundle not found at: $APP_PATH"
    exit 1
fi

echo "📦 Creating disk image for: $APP_PATH"
echo "🎯 Output target: $OUTPUT_DMG"
echo "🏷️  Volume name: $VOLNAME"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_DMG")"
rm -f "$OUTPUT_DMG"

# Check if `create-dmg` CLI tool is available
if command -v create-dmg &>/dev/null; then
    echo "✨ Detected 'create-dmg'. Generating layout-styled disk image..."

    CREATE_DMG_ARGS=(
        --volname "$VOLNAME"
        --window-pos 200 120
        --window-size 600 380
        --icon-size 110
        --text-size 12
        --icon "AppsChannel.app" 160 185
        --app-drop-link 440 185
        --hide-extension "AppsChannel.app"
        --no-internet-enable
    )

    if [ -f "$ICON_PATH" ]; then
        CREATE_DMG_ARGS+=(--volicon "$ICON_PATH")
    fi

    # Execute create-dmg (it exits with 0 or 2 for success with minor warnings)
    set +e
    create-dmg "${CREATE_DMG_ARGS[@]}" "$OUTPUT_DMG" "$APP_PATH"
    CREATE_DMG_STATUS=$?
    set -e

    if [ $CREATE_DMG_STATUS -eq 0 ] || [ $CREATE_DMG_STATUS -eq 2 ]; then
        echo "✅ Created styled DMG successfully."
        ls -lh "$OUTPUT_DMG"
        exit 0
    else
        echo "⚠️  create-dmg failed (code $CREATE_DMG_STATUS). Falling back to native hdiutil..."
    fi
fi

# ==============================================================================
# Native macOS hdiutil Fallback Builder
# ==============================================================================
echo "🔨 Building disk image with native hdiutil..."

STAGING_DIR="$(mktemp -d -t appschannel_dmg_staging_XXXXXX)"
cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

echo "📁 Staging app bundle in: $STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/AppsChannel.app"
ln -s /Applications "$STAGING_DIR/Applications"

# Set volume icon if available
if [ -f "$ICON_PATH" ]; then
    cp "$ICON_PATH" "$STAGING_DIR/.VolumeIcon.icns"
    if command -v SetFile &>/dev/null; then
        SetFile -a C "$STAGING_DIR" || true
    fi
fi

# Create UDZO compressed DMG
hdiutil create \
    -volname "$VOLNAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$OUTPUT_DMG"

echo "✅ DMG created successfully at: $OUTPUT_DMG"
ls -lh "$OUTPUT_DMG"
