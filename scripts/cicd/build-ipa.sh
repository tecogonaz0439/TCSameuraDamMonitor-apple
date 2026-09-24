#!/bin/bash
set -euo pipefail

# 段階② build: iOS / iPadOS 用の .ipa をローカルで作成する。
# 外部作用はない(アップロード経路を持たない)。TestFlight へのアップロードは
# release-testflight.sh が担う。
# 旧 apple_build_ipa スキル(--upload 無し)のロジックを移植したものである。

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT="$DIR/TCSameuraDamMonitor.xcodeproj"
SCHEME="TCSameuraDamMonitor"
APP_NAME="TCSameuraDamMonitor"
TEAM_ID="W4YK6966L9"

METHOD="app-store-connect"
OUTPUT_DIR="$DIR/build/cicd/ipa"

usage() {
    cat <<'EOF'
Usage: build-ipa.sh [--method <method>] [--output <dir>]

  --method METHOD       Export method: app-store-connect (default) | ad-hoc | development
  --output DIR          Output directory (default: <repo>/build/cicd/ipa)
EOF
    exit 1
}

log() { echo "[build-ipa] $*" >&2; }

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
    app-store-connect|ad-hoc|development) ;;
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
    log ".ipa created: $IPA"
else
    log ".ipa not found (export location changed)"
fi
log "Output directory: $OUTPUT_DIR"
