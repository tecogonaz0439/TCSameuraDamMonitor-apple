#!/bin/bash
set -euo pipefail

# 段階② build: macOS 用の .app(developer-id エクスポート)と配布用 zip を作成する。
# 外部作用はない(公証・アップロードの経路を持たない)。公証は release-notarize.sh、
# TestFlight for Mac へのアップロードは将来のリリースフローで扱う。
# 旧 apple_build_macos_app スキル(--notarize / --upload 無し)のロジックを移植したものである。

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT="$DIR/TCSameuraDamMonitor.xcodeproj"
SCHEME="TCSameuraDamMonitor"
APP_NAME="TCSameuraDamMonitor"
TEAM_ID="W4YK6966L9"

METHOD="developer-id"
OUTPUT_DIR="$DIR/build/cicd/macos"

usage() {
    cat <<'EOF'
Usage: build-macos-app.sh [--method <method>] [--output <dir>]

  --method METHOD       Export method: developer-id (default) | app-store-connect | ad-hoc | development
  --output DIR          Output directory (default: <repo>/build/cicd/macos)

App Store Connect API key environment variables (used only for xcodebuild cloud signing):
  TCSAMEURA_ASC_API_KEY_PATH / TCSAMEURA_ASC_API_KEY_ID / TCSAMEURA_ASC_API_ISSUER_ID
EOF
    exit 1
}

log() { echo "[build-macos-app] $*" >&2; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --method) METHOD="$2"; shift ;;
        --output) OUTPUT_DIR="$2"; shift ;;
        -h|--help) usage ;;
        *) usage ;;
    esac
    shift
done

case "$METHOD" in
    developer-id|app-store-connect|ad-hoc|development) ;;
    *) log "Error: invalid method: $METHOD"; usage ;;
esac

ARCHIVE_PATH="$OUTPUT_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$OUTPUT_DIR/export"

mkdir -p "$OUTPUT_DIR"

EXPORT_OPTIONS="$OUTPUT_DIR/ExportOptions.plist"
{
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
    echo '<plist version="1.0">'
    echo '<dict>'
    echo "  <key>method</key><string>$METHOD</string>"
    echo "  <key>teamID</key><string>$TEAM_ID</string>"
    echo '  <key>signingStyle</key><string>automatic</string>'
    echo '  <key>uploadSymbols</key><true/>'
    echo '</dict>'
    echo '</plist>'
} > "$EXPORT_OPTIONS"
log "ExportOptions.plist written: $EXPORT_OPTIONS"

# API キーが環境変数で指定された場合は xcodebuild の認証にも使う。
# Xcode に Apple ID セッションが保存されていないビルド機では、
# 自動署名のプロファイル解決にこの認証が必要になる。
AUTH_FLAGS=()
if [[ -n "${TCSAMEURA_ASC_API_KEY_PATH:-}" ]]; then
    AUTH_FLAGS+=(-authenticationKeyPath "$TCSAMEURA_ASC_API_KEY_PATH")
fi
if [[ -n "${TCSAMEURA_ASC_API_KEY_ID:-}" ]]; then
    AUTH_FLAGS+=(-authenticationKeyID "$TCSAMEURA_ASC_API_KEY_ID")
fi
if [[ -n "${TCSAMEURA_ASC_API_ISSUER_ID:-}" ]]; then
    AUTH_FLAGS+=(-authenticationKeyIssuerID "$TCSAMEURA_ASC_API_ISSUER_ID")
fi

log "Archiving ($METHOD)..."
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    "${AUTH_FLAGS[@]+"${AUTH_FLAGS[@]}"}" \
    > "$OUTPUT_DIR/archive.log" 2>&1 || {
        log "Error: archive failed. See: $OUTPUT_DIR/archive.log"
        tail -20 "$OUTPUT_DIR/archive.log" >&2 || true
        exit 1
    }
grep -E "ARCHIVE SUCCEEDED|ARCHIVE FAILED|BUILD SUCCEEDED|BUILD FAILED" "$OUTPUT_DIR/archive.log" | tail -1 >&2 || true

rm -rf "$EXPORT_PATH"

log "Exporting..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates \
    "${AUTH_FLAGS[@]+"${AUTH_FLAGS[@]}"}" \
    > "$OUTPUT_DIR/export.log" 2>&1 || {
        log "Error: export failed. See: $OUTPUT_DIR/export.log"
        tail -20 "$OUTPUT_DIR/export.log" >&2 || true
        exit 1
    }
grep -E "BUILD SUCCEEDED|BUILD FAILED|DISTRIBUTION SUCCEEDED|DISTRIBUTION FAILED" "$OUTPUT_DIR/export.log" | tail -1 >&2 || true

APP_PATH="$(find "$EXPORT_PATH" -maxdepth 2 -name "*.app" -type d 2>/dev/null | head -1 || true)"
if [[ -z "${APP_PATH:-}" ]]; then
    log "Error: .app not found under $EXPORT_PATH"
    exit 1
fi
log ".app exported: $APP_PATH"

# project.pbxproj を正としてバージョンを取得する。
MARKETING_VERSION="$(grep -m1 'MARKETING_VERSION = ' "$PROJECT/project.pbxproj" | sed 's/.*MARKETING_VERSION = //;s/;//;s/[[:space:]]//g')"
CURRENT_PROJECT_VERSION="$(grep -m1 'CURRENT_PROJECT_VERSION = ' "$PROJECT/project.pbxproj" | sed 's/.*CURRENT_PROJECT_VERSION = //;s/;//;s/[[:space:]]//g')"
if [[ -z "${MARKETING_VERSION:-}" || -z "${CURRENT_PROJECT_VERSION:-}" ]]; then
    log "Error: failed to read version from project.pbxproj"
    exit 1
fi

ZIP_NAME="${APP_NAME}-macos-${MARKETING_VERSION}-${CURRENT_PROJECT_VERSION}.zip"
ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"

make_zip() {
    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
    log "zip created: $ZIP_PATH"
}

make_zip

log "Output directory: $OUTPUT_DIR"
