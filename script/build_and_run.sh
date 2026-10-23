#!/usr/bin/env bash
# [INPUT]: 依赖 SwiftPM、macOS open 与本地演示目标。
# [OUTPUT]: 在用户缓存目录构建并启动演示 App。
# [POS]: 唯一演示启动入口；不触碰其他应用或系统权限。
# [PROTOCOL]: 变更时更新此头部，然后检查 CLAUDE.md
set -euo pipefail
MODE="${1:-run}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME=CUAPermissionDemo
BUNDLE_ID=org.cuapermissionkit.demo
cd "$ROOT"
case "$MODE" in run|--debug|--logs|--telemetry|--verify) ;; *) echo "usage: $0 [--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;; esac
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
swift build --product "$APP_NAME"
BINARY="$(swift build --show-bin-path)/$APP_NAME"
BUNDLE="$HOME/Library/Caches/org.cuapermissionkit.demo/$APP_NAME.app"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$BINARY" "$BUNDLE/Contents/MacOS/$APP_NAME"
cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>CUA Permission Demo</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
case "$MODE" in
run) /usr/bin/open -n "$BUNDLE" ;;
--debug) lldb -- "$BUNDLE/Contents/MacOS/$APP_NAME" ;;
--logs) /usr/bin/open -n "$BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "CUAPermissionDemo"' ;;
--telemetry) /usr/bin/open -n "$BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "org.cuapermissionkit.demo" OR subsystem == "org.cuapermissionkit"' ;;
--verify) /usr/bin/open -n "$BUNDLE"; sleep 1; pgrep -x "$APP_NAME" >/dev/null ;;
esac
