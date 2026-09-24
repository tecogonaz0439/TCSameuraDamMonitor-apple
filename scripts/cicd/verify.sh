#!/bin/bash
set -euo pipefail

# 段階① verify: apple 版の単体テスト(macOS destination、署名なし)を一括実行する。
# 外部作用はない(ローカルの xcodebuild 実行のみ)。成功時に
# build/agent-verify-stamp へコミットハッシュと実行時刻を記録し、
# pre-push hook がこれを確認する。
#
# 環境変数 DEVELOPER_DIR が未設定の場合は、本機の既定値を使う。

DIR="$(cd "$(dirname "$0")/../.." && pwd)"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
XCODEBUILD="$DEVELOPER_DIR/usr/bin/xcodebuild"

PROJECT="$DIR/TCSameuraDamMonitor.xcodeproj"
SCHEME="TCSameuraDamMonitor"
DESTINATION="${APPLE_VERIFY_DESTINATION:-platform=macOS}"

cd "$DIR"
"$XCODEBUILD" test \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO \
  "$@"

mkdir -p build
printf '%s %s\n' "$(git rev-parse HEAD)" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > build/agent-verify-stamp
echo "verify passed: $(cat build/agent-verify-stamp)"
