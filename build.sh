#!/bin/bash
# ============================================================
# 客户电销记录 · 一键构建 .app + .dmg
# 用法:在项目目录执行 ./build.sh
# 依赖:macOS 11+ 自带的 swiftc / sips / iconutil / hdiutil / codesign / curl
#       如果第一次跑提示缺少 swiftc,先装 Xcode CLT:xcode-select --install
# 产物:./客户电销记录-1.0.0.dmg(同目录)
# ============================================================

set -euo pipefail

# ---- 配置 ----
APP_NAME="客户电销记录"
APP_BIN="telesales"
BUNDLE_ID="com.frank.telesales"
VERSION="1.0.0"

# ---- 路径 ----
HERE="$(cd "$(dirname "$0")" && pwd)"
BUILD="$HERE/build"
APP="$BUILD/$APP_NAME.app"
RES="$APP/Contents/Resources"

# ---- 工具检查 ----
if ! command -v swiftc >/dev/null 2>&1; then
  echo "✗ 缺少 swiftc。请先装 Xcode Command Line Tools:" >&2
  echo "  xcode-select --install" >&2
  exit 1
fi

# ---- 清理 ----
rm -rf "$BUILD"
mkdir -p "$APP/Contents/MacOS" "$RES" "$RES/vendor"

# ============================================================
echo "[1/6] 编译 Swift 启动器..."
swiftc -o "$APP/Contents/MacOS/$APP_BIN" "$HERE/AppLauncher.swift" \
  -framework Cocoa -framework WebKit -O

# ============================================================
echo "[2/6] 下载 CDN 依赖到本地(让 .app 完全离线)..."
download() {
  local url=$1 out=$2
  if curl -sSLf "$url" -o "$out"; then
    echo "  ✓ $(basename "$out")"
  else
    echo "  ✗ 下载失败:$url(联网检查一下)" >&2
    exit 1
  fi
}
download "https://cdn.tailwindcss.com" "$RES/vendor/tailwind.js"
download "https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js" "$RES/vendor/html2canvas.min.js"
download "https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js" "$RES/vendor/xlsx.full.min.js"

# ============================================================
echo "[3/6] 拷贝资源 + 把 CDN 引用改成本地路径..."
cp "$HERE/prototype.html" "$RES/prototype.html"
# sed -i '' 是 macOS 语法,原地修改不产生备份
sed -i '' \
  -e 's|https://cdn\.tailwindcss\.com|vendor/tailwind.js|g' \
  -e 's|https://cdn\.jsdelivr\.net/npm/html2canvas@1\.4\.1/dist/html2canvas\.min\.js|vendor/html2canvas.min.js|g' \
  -e 's|https://cdn\.jsdelivr\.net/npm/xlsx@0\.18\.5/dist/xlsx\.full\.min\.js|vendor/xlsx.full.min.js|g' \
  "$RES/prototype.html"
if [ -f "$HERE/manifest.json" ]; then cp "$HERE/manifest.json" "$RES/"; fi
if [ -f "$HERE/icon.svg" ]; then cp "$HERE/icon.svg" "$RES/"; fi
if [ -f "$HERE/sw.js" ]; then cp "$HERE/sw.js" "$RES/"; fi

# ============================================================
echo "[4/6] 从 icon.svg 生成 .icns 应用图标..."
ICONSET="$BUILD/AppIcon.iconset"
mkdir -p "$ICONSET"
if [ -f "$HERE/icon.svg" ]; then
  # iconset 标准命名:每个尺寸 + @2x 版
  for spec in \
    "16:icon_16x16" "32:icon_16x16@2x" \
    "32:icon_32x32" "64:icon_32x32@2x" \
    "128:icon_128x128" "256:icon_128x128@2x" \
    "256:icon_256x256" "512:icon_256x256@2x" \
    "512:icon_512x512" "1024:icon_512x512@2x"; do
    size="${spec%%:*}"
    name="${spec##*:}"
    sips -s format png -z "$size" "$size" "$HERE/icon.svg" --out "$ICONSET/${name}.png" >/dev/null 2>&1 || true
  done
  if iconutil -c icns "$ICONSET" -o "$RES/AppIcon.icns" 2>/dev/null; then
    echo "  ✓ AppIcon.icns 已生成"
  else
    echo "  ⚠ iconutil 失败,跳过(将用默认图标)"
  fi
else
  echo "  ⚠ icon.svg 不存在,跳过"
fi

# ============================================================
echo "[5/6] 写 Info.plist + 临时签名..."
cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP_NAME</string>
  <key>CFBundleDisplayName</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleExecutable</key><string>$APP_BIN</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSSupportsAutomaticTermination</key><true/>
  <key>NSSupportsSuddenTermination</key><true/>
</dict>
</plist>
EOF

# Ad-hoc 签名:本机 Gatekeeper 可接受。首次开会出「未知开发者」,右键 → 打开 → 确认即过
codesign --force --sign - "$APP" 2>/dev/null || echo "  ⚠ codesign 跳过"

# ============================================================
echo "[6/6] 打包 DMG..."
DMG="$HERE/$APP_NAME-$VERSION.dmg"
STAGE="$BUILD/dmg-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov -format UDZO \
  "$DMG" >/dev/null

# ---- 清理中间产物 ----
rm -rf "$BUILD"

# ============================================================
echo ""
echo "✓ 构建完成"
echo "  DMG: $DMG"
echo "  大小:$(du -h "$DMG" | cut -f1)"
echo ""
echo "下一步:"
echo "  1. 双击 DMG → 拖 .app 到 Applications"
echo "  2. 首次打开右键 → 打开 → 确认(绕开 Gatekeeper「未知开发者」)"
echo "  3. 之后从 Launchpad 或 Spotlight 直接启动"
