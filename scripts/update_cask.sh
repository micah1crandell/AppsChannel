#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Update Homebrew Cask with New Version & SHA256 Checksum
# Usage: ./scripts/update_cask.sh <version> <dmg-path> [cask-path]
# ==============================================================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"
DMG_PATH="${2:-$REPO_ROOT/build/Build/Products/Release/AppsChannel.dmg}"
CASK_PATH="${3:-$REPO_ROOT/Casks/appschannel.rb}"

if [ -z "$VERSION" ]; then
    echo "❌ Error: Version argument missing."
    echo "Usage: $0 <version> <dmg-path> [cask-path]"
    exit 1
fi

# Clean tag prefix (v1.0.0 -> 1.0.0)
CLEAN_VERSION="${VERSION#v}"

if [ ! -f "$DMG_PATH" ]; then
    echo "❌ Error: DMG not found at $DMG_PATH"
    exit 1
fi

if [ ! -f "$CASK_PATH" ]; then
    echo "❌ Error: Cask file not found at $CASK_PATH"
    exit 1
fi

SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"

echo "🔄 Updating Cask: $CASK_PATH"
echo "📌 Version: $CLEAN_VERSION"
echo "🔑 SHA256:  $SHA256"

# Update version string
sed -i '' -E "s/version \"[^\"]+\"/version \"${CLEAN_VERSION}\"/" "$CASK_PATH"

# Update sha256 string (matches :no_check or existing sha256 hash)
sed -i '' -E "s/sha256 (:no_check|\"[a-fA-F0-9]{64}\").*/sha256 \"${SHA256}\"/" "$CASK_PATH"

echo "✅ Cask updated successfully:"
git diff "$CASK_PATH" || cat "$CASK_PATH"
