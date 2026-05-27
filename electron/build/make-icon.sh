#!/usr/bin/env bash
# 把 ../../icon.svg 渲染成 build/icon.icns,供 electron-builder 打包使用。
# 只依赖 macOS 自带工具:sips、qlmanage、iconutil。
set -euo pipefail

cd "$(dirname "$0")"

SRC_SVG="../../icon.svg"
WORK_PNG="icon-1024.png"
ICONSET_DIR="icon.iconset"
OUT_ICNS="icon.icns"

if [[ ! -f "$SRC_SVG" ]]; then
  echo "[icon] 找不到源 SVG: $SRC_SVG" >&2
  exit 1
fi

# 跳过重复生成(SVG 没变就不重新打)
if [[ -f "$OUT_ICNS" && "$OUT_ICNS" -nt "$SRC_SVG" ]]; then
  echo "[icon] icon.icns 已是最新,跳过"
  exit 0
fi

rm -f "$WORK_PNG"

# 优先 sips(直接 SVG → PNG,macOS 11+ 支持)
echo "[icon] 尝试 sips 渲染 SVG → 1024x1024 PNG"
if sips -s format png -z 1024 1024 "$SRC_SVG" --out "$WORK_PNG" >/dev/null 2>&1; then
  echo "[icon] sips 成功"
else
  echo "[icon] sips 失败,改用 qlmanage"
  qlmanage -t -s 1024 -o . "$SRC_SVG" >/dev/null 2>&1
  GENERATED_PNG="$(basename "$SRC_SVG").png"
  if [[ -f "$GENERATED_PNG" ]]; then
    mv "$GENERATED_PNG" "$WORK_PNG"
  else
    echo "[icon] qlmanage 也失败了。请安装 librsvg:brew install librsvg,然后用 rsvg-convert -w 1024 -h 1024 $SRC_SVG -o $WORK_PNG" >&2
    exit 1
  fi
fi

if [[ ! -f "$WORK_PNG" ]]; then
  echo "[icon] PNG 没生成,无法继续" >&2
  exit 1
fi

echo "[icon] 生成 .iconset 各尺寸"
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"
for size in 16 32 64 128 256 512; do
  sips -z "$size" "$size" "$WORK_PNG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  size2x=$((size * 2))
  sips -z "$size2x" "$size2x" "$WORK_PNG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done
# 512@2x = 1024,iconutil 必须有
cp "$WORK_PNG" "$ICONSET_DIR/icon_512x512@2x.png"

echo "[icon] iconutil 打包 → icon.icns"
iconutil -c icns "$ICONSET_DIR" -o "$OUT_ICNS"

echo "[icon] 清理中间文件"
rm -rf "$ICONSET_DIR" "$WORK_PNG"

echo "[icon] 完成:$(pwd)/$OUT_ICNS"
