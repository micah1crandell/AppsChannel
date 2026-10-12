#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Generate / Update Sparkle appcast.xml for AppsChannel
# Usage: ./scripts/generate_appcast.sh <version> <zip-path> [ed25519-signature]
# ==============================================================================

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-}"
ZIP_PATH="${2:-$REPO_ROOT/build/Build/Products/Release/AppsChannel.zip}"
SIGNATURE="${3:-}"
APPCAST_FILE="${4:-$REPO_ROOT/appcast.xml}"
REPO_URL="https://github.com/micah1crandell/AppsChannel"

if [ -z "$VERSION" ]; then
    echo "❌ Error: Version argument missing."
    echo "Usage: $0 <version> <zip-path> [ed25519-signature] [appcast-path]"
    exit 1
fi

CLEAN_VERSION="${VERSION#v}"

if [ ! -f "$ZIP_PATH" ]; then
    echo "❌ Error: ZIP archive not found at: $ZIP_PATH"
    exit 1
fi

FILE_SIZE="$(stat -f%z "$ZIP_PATH" 2>/dev/null || stat -c%s "$ZIP_PATH" 2>/dev/null)"
PUB_DATE="$(date -R 2>/dev/null || date "+%a, %d %b %Y %H:%M:%S %z")"
DOWNLOAD_URL="${REPO_URL}/releases/download/v${CLEAN_VERSION}/AppsChannel.zip"
RELEASE_NOTES_URL="${REPO_URL}/releases/tag/v${CLEAN_VERSION}"

BUILD_VERSION="${5:-}"
if [ -z "$BUILD_VERSION" ]; then
    APP_INFO_PLIST="$(dirname "$ZIP_PATH")/AppsChannel.app/Contents/Info.plist"
    if [ -f "$APP_INFO_PLIST" ]; then
        BUILD_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_INFO_PLIST" 2>/dev/null || defaults read "$APP_INFO_PLIST" CFBundleVersion 2>/dev/null || echo "")"
    fi
fi
if [ -z "$BUILD_VERSION" ] && [ -f "$REPO_ROOT/AppsChannel.xcodeproj/project.pbxproj" ]; then
    BUILD_VERSION="$(grep -m1 "CURRENT_PROJECT_VERSION" "$REPO_ROOT/AppsChannel.xcodeproj/project.pbxproj" | tr -d '[:space:];' | cut -d'=' -f2 2>/dev/null || echo "")"
fi
if [ -z "$BUILD_VERSION" ]; then
    BUILD_VERSION="${CLEAN_VERSION}"
fi

SIG_ATTR=""
if [ -n "$SIGNATURE" ]; then
    SIG_ATTR="sparkle:edSignature=\"$SIGNATURE\""
fi

ITEM_XML="        <item>
            <title>AppsChannel ${CLEAN_VERSION}</title>
            <sparkle:releaseNotesLink>${RELEASE_NOTES_URL}</sparkle:releaseNotesLink>
            <pubDate>${PUB_DATE}</pubDate>
            <enclosure
                url=\"${DOWNLOAD_URL}\"
                sparkle:version=\"${BUILD_VERSION}\"
                sparkle:shortVersionString=\"${CLEAN_VERSION}\"
                length=\"${FILE_SIZE}\"
                ${SIG_ATTR}
                type=\"application/octet-stream\" />
        </item>"

if [ ! -f "$APPCAST_FILE" ]; then
    echo "📄 Creating initial $APPCAST_FILE..."
    cat <<EOF > "$APPCAST_FILE"
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>AppsChannel Updates</title>
        <link>https://raw.githubusercontent.com/micah1crandell/AppsChannel/main/appcast.xml</link>
        <description>Most recent updates for AppsChannel launcher.</description>
        <language>en</language>
${ITEM_XML}
    </channel>
</rss>
EOF
else
    echo "🔄 Appending new release to $APPCAST_FILE..."
    # Check if this version already exists in appcast
    if grep -q "sparkle:shortVersionString=\"${CLEAN_VERSION}\"" "$APPCAST_FILE"; then
        echo "⚠️  Version ${CLEAN_VERSION} already exists in appcast.xml. Skipping duplicate entry."
    else
        # Insert new item right after <language>en</language>
        python3 - <<PYEOF
import re

with open("${APPCAST_FILE}", "r", encoding="utf-8") as f:
    content = f.read()

item_text = """${ITEM_XML}"""
pattern = r"(<language>[^<]+</language>)"
replacement = r"\1\n" + item_text

new_content = re.sub(pattern, replacement, content, count=1)
with open("${APPCAST_FILE}", "w", encoding="utf-8") as f:
    f.write(new_content)
PYEOF
    fi
fi

echo "✅ $APPCAST_FILE updated successfully."
