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
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$ROOT/Assets/DemoIcon.icns" "$BUNDLE/Contents/Resources/DemoIcon.icns"
# Xcode 27 编译原生分层图标；旧工具链使用同源静态图标。
XCODE_MAJOR="$(xcodebuild -version 2>/dev/null | sed -n 's/^Xcode \([0-9]*\).*/\1/p' || true)"
if [[ "${XCODE_MAJOR:-0}" -ge 27 ]]; then
    xcrun actool "$ROOT/Assets/DemoIcon.icon" --compile "$BUNDLE/Contents/Resources" \
        --platform macosx --minimum-deployment-target 12.0 --app-icon DemoIcon \
        --output-partial-info-plist "$BUNDLE/Contents/Resources/IconInfo.plist"
else
    rm -f "$BUNDLE/Contents/Resources/Assets.car"
fi
cp "$BINARY" "$BUNDLE/Contents/MacOS/$APP_NAME"
cat > "$BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
<key>CFBundleName</key><string>CUA Permission Demo</string>
<key>CFBundleIconFile</key><string>DemoIcon</string>
<key>CFBundleIconName</key><string>DemoIcon</string>
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
