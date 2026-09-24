#!/bin/bash
set -euo pipefail

# Debug ビルドをシミュレータ / 実機(iPhone / iPad)へビルド・インストールする。
# - シミュレータへのインストールは許可不要。
# - 実機へのインストールは許可制(提案 1.3 の A8)。実機には TestFlight バイナリや
#   開発用署名バイナリがインストールされている可能性があるため、実行前に上書きの
#   同意を確認する。対話確認は --yes を付けた場合のみ省略する。
# macOS へのインストールに相当する操作は、build-macos-app.sh の .app を起動する
# ことで行う(本スクリプトの対象外)。
# 旧 apple_install_app スキルのロジックを移植したものである。

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT="$DIR/TCSameuraDamMonitor.xcodeproj"
SCHEME="TCSameuraDamMonitor"
BUNDLE_ID="net.tecogonaz.TCSameuraDamMonitor"
BUILD_DIR="$DIR/build/cicd/install"
DERIVED_DATA="$BUILD_DIR/DerivedData"
ASSUME_YES="false"

usage() {
    cat <<'EOF'
Usage: install-apple.sh [--all] [--device <name>] [--build-only] [--list] [--yes]

  --all          Install to all booted simulators and connected devices
  --device NAME  Install to a specific device by name
  --build-only   Build only, do not install
  --list         List available devices only
  --yes          Skip the interactive consent for physical devices
                 (requires prior consent from the developer)
EOF
    exit 1
}

log() { echo "[install-apple] $*" >&2; }

list_devices() {
    echo "=== Booted Simulators ==="
    xcrun simctl list devices available 2>/dev/null | grep -E "\(Booted\)" \
        | sed -E 's/^[[:space:]]+(.+) \(([^)]+)\) \((Booted)\)/\1  \2/' || true
    echo ""
    echo "=== Connected Real Devices ==="
    local count=0
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showdestinations 2>/dev/null \
        | grep "platform:iOS" | grep -v "Simulator" \
        | sed -E 's/.*name:([^,}]+).*id:([A-Fa-f0-9-]+).*/\1  \2/' | while read line; do
        echo "$line"
        count=$((count + 1))
    done
    if [[ $count -eq 0 ]]; then
        echo "(none)"
    fi
}

find_booted_simulator_udid() {
    xcrun simctl list devices available 2>/dev/null \
        | grep -E "\(Booted\)" \
        | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/' || true
}

find_real_device_udids() {
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showdestinations 2>/dev/null \
        | grep "platform:iOS" | grep -v "Simulator" \
        | grep -v "placeholder" \
        | sed -E 's/.*id:([A-Fa-f0-9-]+).*/\1/' || true
}

find_device_by_name() {
    local name="$1"
    local udid
    udid=$(xcrun simctl list devices available 2>/dev/null \
        | grep "$name (" | grep "(Booted)" \
        | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/' | head -1)
    if [[ -n "$udid" ]]; then
        echo "$udid"
        return 0
    fi
    udid=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showdestinations 2>/dev/null \
        | grep "platform:iOS" | grep -v "Simulator" | grep -i "$name" \
        | sed -E 's/.*id:([A-Fa-f0-9-]+).*/\1/' | head -1)
    if [[ -n "$udid" ]]; then
        echo "$udid"
        return 0
    fi
    echo ""
}

build_for_device() {
    local udid="$1"
    log "Building for device: $udid"
    xcodebuild -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "id=$udid" \
        -derivedDataPath "$DERIVED_DATA" \
        CODE_SIGNING_ALLOWED=YES \
        build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" | tail -5
}

find_app_path() {
    find "$DERIVED_DATA/Build/Products" -name "TCSameuraDamMonitor.app" -type d 2>/dev/null | head -1
}

install_to_simulator() {
    local udid="$1"
    local app="$2"
    log "Installing to simulator: $udid"
    xcrun simctl install "$udid" "$app"
    log "Launching on simulator: $udid"
    xcrun simctl launch "$udid" "$BUNDLE_ID"
}

install_to_device() {
    local udid="$1"
    local app="$2"
    log "Installing to device: $udid"
    xcrun devicectl device install app --device "$udid" "$app"
    echo "To launch on device, unlock and tap the app icon."
}

# --- Main ---
MODE=""
DEVICE_NAME=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all) MODE="all" ;;
        --device) MODE="device"; DEVICE_NAME="$2"; shift ;;
        --build-only) MODE="build-only" ;;
        --list) MODE="list" ;;
        --yes) ASSUME_YES="true" ;;
        *) usage ;;
    esac
    shift
done

confirm_physical_install() {
    # A8: 実機へのインストールは無条件に同意を確認する。
    if [[ "$ASSUME_YES" == "true" ]]; then
        return 0
    fi
    log "A physical device was selected. A debug build will be installed over the existing app."
    log "The device may already have a TestFlight or development-signed binary installed."
    read -r -p "Install (overwriting the existing app if any)? [y/N] " REPLY
    if [[ ! "$REPLY" =~ ^[yY]$ ]]; then
        log "Aborted by user."
        exit 1
    fi
}

if [[ -z "$MODE" ]]; then
    usage
fi

if [[ "$MODE" == "list" ]]; then
    list_devices
    exit 0
fi

if [[ "$MODE" == "build-only" ]]; then
    log "Building for generic iOS device"
    xcodebuild -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination 'generic/platform=iOS' \
        -derivedDataPath "$DERIVED_DATA" \
        CODE_SIGNING_ALLOWED=NO \
        build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)" | tail -5
    log "Build complete. App at: $(find_app_path)"
    exit 0
fi

rm -rf "$DERIVED_DATA"

if [[ "$MODE" == "device" ]]; then
    UDID=$(find_device_by_name "$DEVICE_NAME")
    if [[ -z "$UDID" ]]; then
        log "Error: Device not found or not available: $DEVICE_NAME"
        list_devices
        exit 1
    fi
    build_for_device "$UDID"
    APP=$(find_app_path)
    if [[ -z "$APP" ]]; then
        log "Error: Could not find built .app"
        exit 1
    fi
    log "App path: $APP"
    if xcrun simctl list devices available 2>/dev/null | grep -q "$UDID"; then
        install_to_simulator "$UDID" "$APP"
    else
        confirm_physical_install
        install_to_device "$UDID" "$APP"
    fi
    exit 0
fi

if [[ "$MODE" == "all" ]]; then
    INSTALLED=0
    SIM_UDIDS=$(find_booted_simulator_udid)
    DEV_UDIDS=$(find_real_device_udids)
    if [[ -n "$SIM_UDIDS" ]]; then
        FIRST_UDID=$(echo "$SIM_UDIDS" | head -1)
        log "Building for iOS Simulator ($FIRST_UDID)..."
        build_for_device "$FIRST_UDID"
        APP=$(find_app_path)
        if [[ -n "$APP" ]]; then
            log "App path: $APP"
            for UDID in $SIM_UDIDS; do
                install_to_simulator "$UDID" "$APP"
                INSTALLED=$((INSTALLED + 1))
            done
        fi
    fi
    if [[ -n "$DEV_UDIDS" ]]; then
        confirm_physical_install
        rm -rf "$DERIVED_DATA"
        for UDID in $DEV_UDIDS; do
            build_for_device "$UDID"
            APP=$(find_app_path)
            if [[ -n "$APP" ]]; then
                install_to_device "$UDID" "$APP"
                INSTALLED=$((INSTALLED + 1))
            fi
        done
    fi
    if [[ $INSTALLED -eq 0 ]]; then
        log "No available devices found."
        list_devices
        exit 1
    fi
    log "Installed to $INSTALLED device(s)."
    exit 0
fi
