#!/bin/bash
set -euo pipefail

# 段階③ release(許可制: Apple の公証サービスへの送信を伴う): macOS 用 zip を
# notarytool で公証し、チケットを .app へ staple して zip を再作成する。
# 対話確認を内蔵し、--yes を付けた場合のみ省略する。再実行の判断は制作者が行う。
# 入力は build-macos-app.sh の出力(<output>/export/*.app と <output>/<zip>)を使う。
# 旧 apple_build_macos_app スキルの --notarize 経路を移植したものである。

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT="$DIR/TCSameuraDamMonitor.xcodeproj"
APP_NAME="TCSameuraDamMonitor"
OUTPUT_DIR="$DIR/build/cicd/macos"
ASSUME_YES="false"

usage() {
    cat <<'EOF'
Usage: release-notarize.sh [--output <dir>] [--yes]

  --output DIR       Build output directory produced by build-macos-app.sh
                     (default: <repo>/build/cicd/macos)
  --yes              Skip the interactive confirmation (requires prior consent from the developer)

Environment variables for App Store Connect authentication:
  TCSAMEURA_ASC_API_KEY_PATH / TCSAMEURA_ASC_API_KEY_ID / TCSAMEURA_ASC_API_ISSUER_ID
EOF
    exit 1
}

log() { echo "[release-notarize] $*" >&2; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) OUTPUT_DIR="$2"; shift ;;
        --yes) ASSUME_YES="true" ;;
        -h|--help) usage ;;
        *) usage ;;
    esac
    shift
done

API_KEY_PATH="${TCSAMEURA_ASC_API_KEY_PATH:-}"
API_KEY_ID="${TCSAMEURA_ASC_API_KEY_ID:-}"
API_ISSUER_ID="${TCSAMEURA_ASC_API_ISSUER_ID:-}"

if [[ -z "$API_KEY_PATH" || -z "$API_KEY_ID" || -z "$API_ISSUER_ID" ]]; then
    log "Error: App Store Connect API credentials are not fully set."
    log "Export TCSAMEURA_ASC_API_KEY_PATH / TCSAMEURA_ASC_API_KEY_ID / TCSAMEURA_ASC_API_ISSUER_ID."
    exit 1
fi

if [[ ! -f "$API_KEY_PATH" ]]; then
    log "Error: API key file not found: $API_KEY_PATH"
    exit 1
fi
API_KEY_PATH="$(cd "$(dirname "$API_KEY_PATH")" && pwd)/$(basename "$API_KEY_PATH")"

APP_PATH="$(find "$OUTPUT_DIR/export" -maxdepth 2 -name "*.app" -type d 2>/dev/null | head -1 || true)"
if [[ -z "${APP_PATH:-}" ]]; then
    log "Error: .app not found under $OUTPUT_DIR/export. Run build-macos-app.sh first."
    exit 1
fi

# project.pbxproj を正としてバージョンを取得する。
MARKETING_VERSION="$(grep -m1 'MARKETING_VERSION = ' "$PROJECT/project.pbxproj" | sed 's/.*MARKETING_VERSION = //;s/;//;s/[[:space:]]//g')"
CURRENT_PROJECT_VERSION="$(grep -m1 'CURRENT_PROJECT_VERSION = ' "$PROJECT/project.pbxproj" | sed 's/.*CURRENT_PROJECT_VERSION = //;s/;//;s/[[:space:]]//g')"
if [[ -z "${MARKETING_VERSION:-}" || -z "${CURRENT_PROJECT_VERSION:-}" ]]; then
    log "Error: failed to read version from project.pbxproj"
    exit 1
fi

ZIP_NAME="${APP_NAME}-macos-${MARKETING_VERSION}-${CURRENT_PROJECT_VERSION}.zip"
ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"
if [[ ! -f "$ZIP_PATH" ]]; then
    log "Error: zip not found: $ZIP_PATH. Run build-macos-app.sh first."
    exit 1
fi

if [[ "$ASSUME_YES" != "true" ]]; then
    log "This will submit $ZIP_PATH to the Apple notarization service."
    read -r -p "Proceed with notarization? [y/N] " REPLY
    if [[ ! "$REPLY" =~ ^[yY]$ ]]; then
        log "Aborted by user."
        exit 1
    fi
fi

make_zip() {
    rm -f "$ZIP_PATH"
    ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
    log "zip created: $ZIP_PATH"
}

log "Submitting for notarization (this usually takes a few minutes)..."
xcrun notarytool submit "$ZIP_PATH" \
    --key "$API_KEY_PATH" \
    --key-id "$API_KEY_ID" \
    --issuer "$API_ISSUER_ID" \
    --wait \
    > "$OUTPUT_DIR/notarize.log" 2>&1 || {
        log "Error: notarization failed. See: $OUTPUT_DIR/notarize.log"
        tail -20 "$OUTPUT_DIR/notarize.log" >&2 || true
        exit 1
    }
tail -5 "$OUTPUT_DIR/notarize.log" >&2 || true
if ! grep -q "status: Accepted" "$OUTPUT_DIR/notarize.log"; then
    log "Error: notarization not accepted. See: $OUTPUT_DIR/notarize.log"
    exit 1
fi
log "Notarization accepted. Stapling ticket to .app..."
xcrun stapler staple "$APP_PATH" >> "$OUTPUT_DIR/notarize.log" 2>&1 || {
    log "Error: staple failed. See: $OUTPUT_DIR/notarize.log"
    tail -20 "$OUTPUT_DIR/notarize.log" >&2 || true
    exit 1
}
log "Staple succeeded. Re-creating zip with stapled .app..."
make_zip

log "Output directory: $OUTPUT_DIR"
