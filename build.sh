#!/usr/bin/env bash
# Builds Zonely.app. Set UNIVERSAL=1 for an arm64 + x86_64 binary.
set -euo pipefail
cd "$(dirname "$0")"

APP=Zonely
CONFIG=${CONFIG:-release}
ARCH_FLAGS=()
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    ARCH_FLAGS=(--arch arm64 --arch x86_64)
fi

echo "==> Building ($CONFIG${UNIVERSAL:+, universal})"
swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN="$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/$APP"

OUT="build/$APP.app"
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/$APP"
cp Resources/Info.plist "$OUT/Contents/Info.plist"

if [[ ! -f Resources/AppIcon.icns ]] && command -v swift >/dev/null; then
    echo "==> Generating app icon"
    swift Tools/GenerateIcon.swift Resources/AppIcon.icns >/dev/null 2>&1 || true
fi
[[ -f Resources/AppIcon.icns ]] && cp Resources/AppIcon.icns "$OUT/Contents/Resources/AppIcon.icns"

echo "==> Signing (ad-hoc)"
codesign --force --sign - "$OUT" >/dev/null

echo "==> Built $OUT"
