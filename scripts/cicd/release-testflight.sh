#!/bin/bash
set -euo pipefail

# 段階③ release(許可制: 提案 1.3 の A4): iOS / iPadOS 用アーカイブを
# App Store Connect(TestFlight)へアップロードする。実行前に制作者の許可を得ること。
# 対話確認を内蔵し、--yes を付けた場合のみ省略する。
# 認証は App Store Connect API キー(.p8、共通リポジトリ直下にローカル配置)を使う。
# 旧 apple_build_ipa スキルの --upload 経路を移植したものである。

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT="$DIR/TCSameuraDamMonitor.xcodeproj"
SCHEME="TCSameuraDamMonitor"
APP_NAME="TCSameuraDamMonitor"
TEAM_ID="W4YK6966L9"

METHOD="app-store-connect"
OUTPUT_DIR="$DIR/build/cicd/testflight-upload"
ASSUME_YES="false"

usage() {
    cat <<'EOF'
Usage: release-testflight.sh [--output <dir>] [--yes]

Environment variables for App Store Connect authentication:
  TCSAMEURA_ASC_API_KEY_PATH    .p8 key path (required)
  TCSAMEURA_ASC_API_KEY_ID      key ID (required)
  TCSAMEURA_ASC_API_ISSUER_ID   issuer ID (required)

  --output DIR       Output directory (default: <repo>/build/cicd/testflight-upload)
  --yes              Skip the interactive confirmation (requires prior consent from the developer)
EOF
    exit 1
}

log() { echo "[release-testflight] $*" >&2; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) OUTPUT_DIR="$2"; shift ;;
        --yes) ASSUME_YES="true" ;;
        -h|--help) usage ;;
        *) usage ;;
    esac
    shift
done

if [[ "$ASSUME_YES" != "true" ]]; then
    log "This will upload the iOS archive to App Store Connect (TestFlight)."
    read -r -p "Proceed with the upload? [y/N] " REPLY
    if [[ ! "$REPLY" =~ ^[yY]$ ]]; then
        log "Aborted by user."
        exit 1
    fi
fi

API_KEY_PATH="${TCSAMEURA_ASC_API_KEY_PATH:-}"
API_KEY_ID="${TCSAMEURA_ASC_API_KEY_ID:-}"
API_ISSUER_ID="${TCSAMEURA_ASC_API_ISSUER_ID:-}"

if [[ -z "$API_KEY_PATH" || -z "$API_KEY_ID" || -z "$API_ISSUER_ID" ]]; then
    log "Error: App Store Connect API credentials are not fully set."
    log "Export TCSAMEURA_ASC_API_KEY_PATH / TCSAMEURA_ASC_API_KEY_ID / TCSAMEURA_ASC_API_ISSUER_ID."
    exit 1
fi

if [[ ! -f "$API_KEY_PATH" ]]; then
    log "Error: API key not found: $API_KEY_PATH"
    exit 1
fi

ARCHIVE_PATH="$OUTPUT_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$OUTPUT_DIR/export"

mkdir -p "$OUTPUT_DIR"

UPLOAD="true"
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
    if [[ "$UPLOAD" == "true" ]]; then
        echo '  <key>destination</key><string>upload</string>'
    fi
    echo '</dict>'
    echo '</plist>'
} > "$EXPORT_OPTIONS"
log "ExportOptions.plist written: $EXPORT_OPTIONS"

AUTH_FLAGS=(-authenticationKeyPath "$API_KEY_PATH" -authenticationKeyID "$API_KEY_ID" -authenticationKeyIssuerID "$API_ISSUER_ID")

log "Archiving ($METHOD)..."
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    "${AUTH_FLAGS[@]+"${AUTH_FLAGS[@]}"}" \
    > "$OUTPUT_DIR/archive.log" 2>&1 || {
        log "Error: archive failed. See: $OUTPUT_DIR/archive.log"
        tail -20 "$OUTPUT_DIR/archive.log" >&2 || true
        exit 1
    }
grep -E "BUILD SUCCEEDED|BUILD FAILED" "$OUTPUT_DIR/archive.log" | tail -1 >&2 || true

rm -rf "$EXPORT_PATH"

log "Exporting/uploading..."
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
grep -E "BUILD SUCCEEDED|BUILD FAILED|DISTRIBUTION SUCCEEDED|DISTRIBUTION FAILED|UPLOAD SUCCEEDED|UPLOAD FAILED" "$OUTPUT_DIR/export.log" | tail -1 >&2 || true

IPA=$(find "$EXPORT_PATH" -name "*.ipa" -type f 2>/dev/null | head -1 || true)
if [[ -n "$IPA" ]]; then
    log ".ipa created (unexpected in upload mode): $IPA"
else
    log ".ipa not found (upload mode)"
fi
log "Output directory: $OUTPUT_DIR"
