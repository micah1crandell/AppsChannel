#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Inside-Out Code Signing for AppsChannel & Embedded Frameworks
# Adheres strictly to Apple Technical Note TN3126: Inside-Out Code Signing
# ==============================================================================

APP_PATH="${1:-build/Build/Products/Release/AppsChannel.app}"
SIGNING_IDENTITY="${2:--}"
ENTITLEMENTS="${3:-AppsChannel/AppsChannel.entitlements}"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Application bundle not found at: $APP_PATH"
    exit 1
fi

echo "✍️  Signing Application Bundle (Inside-Out): $APP_PATH"
echo "🔏 Identity: $SIGNING_IDENTITY"

SIGN_FLAGS=(--force --verbose)
if [ "$SIGNING_IDENTITY" != "-" ]; then
    SIGN_FLAGS+=(--options runtime --timestamp)
fi

# 1. Sign standalone executable helper tools inside frameworks (e.g. Sparkle's Autoupdate)
if [ -d "$APP_PATH/Contents/Frameworks" ]; then
    find "$APP_PATH/Contents/Frameworks" -type f -name "Autoupdate" 2>/dev/null | while read -r bin; do
        echo "  -> Signing standalone tool: $bin"
        codesign "${SIGN_FLAGS[@]}" --sign "$SIGNING_IDENTITY" "$bin"
    done

    # 2. Sign any loose dynamic libraries in Frameworks
    find "$APP_PATH/Contents/Frameworks" -type f -name "*.dylib" 2>/dev/null | while read -r dylib; do
        echo "  -> Signing dynamic library: $dylib"
        codesign "${SIGN_FLAGS[@]}" --sign "$SIGNING_IDENTITY" "$dylib"
    done

    # 3. Sign nested XPC services inside frameworks (e.g. Sparkle XPCServices)
    find "$APP_PATH/Contents/Frameworks" -type d -name "*.xpc" 2>/dev/null | while read -r xpc; do
        echo "  -> Signing nested XPC Service: $xpc"
        codesign "${SIGN_FLAGS[@]}" --sign "$SIGNING_IDENTITY" "$xpc"
    done

    # 4. Sign nested helper app bundles inside frameworks (e.g. Updater.app)
    find "$APP_PATH/Contents/Frameworks" -type d -name "*.app" 2>/dev/null | while read -r helperApp; do
        echo "  -> Signing nested Helper App: $helperApp"
        codesign "${SIGN_FLAGS[@]}" --sign "$SIGNING_IDENTITY" "$helperApp"
    done

    # 5. Sign enclosing framework bundles
    find "$APP_PATH/Contents/Frameworks" -type d -name "*.framework" 2>/dev/null | while read -r framework; do
        echo "  -> Signing Framework bundle: $framework"
        codesign "${SIGN_FLAGS[@]}" --sign "$SIGNING_IDENTITY" "$framework"
    done
fi

# 5. Sign the main application bundle (without --deep so nested signatures are preserved)
echo "  -> Signing Main App Bundle: $APP_PATH"
APP_SIGN_ARGS=("${SIGN_FLAGS[@]}" --sign "$SIGNING_IDENTITY")
if [ -f "$ENTITLEMENTS" ] && [ "$SIGNING_IDENTITY" != "-" ]; then
    APP_SIGN_ARGS+=(--entitlements "$ENTITLEMENTS")
fi
codesign "${APP_SIGN_ARGS[@]}" "$APP_PATH"

echo "🔍 Verifying complete code signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo "✅ Code signature verified successfully."
