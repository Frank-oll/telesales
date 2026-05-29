#!/usr/bin/env bash
#
# 一键发版:同步版本号 → 写更新日志 → 打包 dmg → 发 GitHub Release → 更新「更新清单」Gist
#
# 用法:
#   ./release.sh <version> "更新要点1" "更新要点2" ...
# 例:
#   ./release.sh 1.3.0 "新增「关于」页" "升级后展示本次更新内容" "历史会话支持删除"
#
# 做完后,所有 ≥1.1.0 的用户下次打开 App 会收到更新提示。
# 依赖:node、gh(已登录且对仓库/该 Gist 有写权限)、electron 目录已 npm install。

set -euo pipefail

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "❌ 用法: ./release.sh <version> \"更新要点1\" \"更新要点2\" ..."
  exit 1
fi
shift
NOTES=("$@")
if [ "${#NOTES[@]}" -eq 0 ]; then
  echo "❌ 请至少提供一条更新要点(会显示在 App 的「本次更新」弹窗里)"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")" && pwd)"
PROTO="$ROOT/prototype.html"
PKG="$ROOT/electron/package.json"
DMG="$ROOT/electron/dist/Telesales-${VERSION}-arm64.dmg"
HELPER_ZIP="/tmp/Telesales-Unlock-Helper.zip"
MANIFEST="/tmp/telesales-latest.json"
GIST_ID="1152e135c53e5dc2ad6e7bce798ac887"
REPO="Frank-oll/telesales"
DMG_URL="https://github.com/${REPO}/releases/download/v${VERSION}/Telesales-${VERSION}-arm64.dmg"

# 当前分支提醒(Release 基于远程 main)
BRANCH="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
if [ "$BRANCH" != "main" ]; then
  echo "⚠️  当前在分支 '$BRANCH',Release 会基于远程 main。建议先合并到 main 再发版。"
  read -r -p "仍要继续吗?(y/N) " ans
  [ "$ans" = "y" ] || [ "$ans" = "Y" ] || { echo "已取消"; exit 1; }
fi

echo "▶ 1/6 写入版本号 v${VERSION} 与更新日志 …"
PROTO="$PROTO" PKG="$PKG" VERSION="$VERSION" NOTES="$(printf '%s\n' "${NOTES[@]}")" node -e '
  const fs = require("fs");
  const { PROTO, PKG, VERSION, NOTES } = process.env;
  const notes = NOTES.split("\n").filter(Boolean);
  // package.json 版本
  const pkg = JSON.parse(fs.readFileSync(PKG, "utf8"));
  pkg.version = VERSION;
  fs.writeFileSync(PKG, JSON.stringify(pkg, null, 2) + "\n");
  // prototype.html:APP_VERSION + RELEASES 条目
  let html = fs.readFileSync(PROTO, "utf8");
  if (!/const APP_VERSION = .*;/.test(html)) { console.error("找不到 APP_VERSION"); process.exit(1); }
  html = html.replace(/const APP_VERSION = .*;/, "const APP_VERSION = " + JSON.stringify(VERSION) + ";");
  const anchor = "// __RELEASES_INSERT__";
  if (!html.includes(anchor)) { console.error("找不到 RELEASES 锚点注释"); process.exit(1); }
  const entry = "{ version: " + JSON.stringify(VERSION) + ", items: [\n" +
    notes.map(n => "      " + JSON.stringify(n) + ",").join("\n") +
    "\n    ] },";
  html = html.replace(anchor, anchor + "\n    " + entry);
  fs.writeFileSync(PROTO, html);
  console.log("  ✓ package.json / prototype.html 已更新");
'

echo "▶ 2/6 打包 dmg(npm run dist)…"
( cd "$ROOT/electron" && npm run dist >/dev/null )
[ -f "$DMG" ] || { echo "❌ 未找到打包产物: $DMG"; exit 1; }
echo "  ✓ $DMG"

echo "▶ 3/6 打包解锁助手 …"
rm -f "$HELPER_ZIP"
zip -j "$HELPER_ZIP" "$ROOT/tools/unlock-telesales.command" >/dev/null
echo "  ✓ $HELPER_ZIP"

echo "▶ 4/6 提交并推送版本改动 …"
( cd "$ROOT" && git add prototype.html electron/package.json && git commit -m "release: v${VERSION}" && git push )

echo "▶ 5/6 创建 GitHub Release v${VERSION} …"
RELEASE_BODY="## 客户电销记录 v${VERSION}

### 本次更新
$(printf -- '- %s\n' "${NOTES[@]}")
### 安装(Apple Silicon / M 系列芯片)
1. 下载 \`Telesales-${VERSION}-arm64.dmg\`,拖入「应用程序」覆盖旧版。
2. 若提示「已损坏 / 无法验证开发者」(未签名),下载 \`Telesales-Unlock-Helper.zip\` 解压双击 \`unlock-telesales.command\` 一键解锁;或终端执行 \`xattr -dr com.apple.quarantine /Applications/Telesales.app\`。

> 已安装 1.1.0+ 的用户,打开 App 顶部会自动提示升级。"
gh release create "v${VERSION}" "$DMG" "$HELPER_ZIP" \
  --target main --title "v${VERSION}" --notes "$RELEASE_BODY"

echo "▶ 6/6 更新「更新清单」Gist …"
BANNER_NOTE="${NOTES[0]}"
cat > "$MANIFEST" <<JSON
{
  "latest": "${VERSION}",
  "url": "${DMG_URL}",
  "notes": "${BANNER_NOTE}"
}
JSON
gh gist edit "$GIST_ID" "$MANIFEST"

echo ""
echo "✅ v${VERSION} 发布完成!"
echo "   • Release: https://github.com/${REPO}/releases/tag/v${VERSION}"
echo "   • 旧版用户(≥1.1.0)下次打开即会收到更新提示。"
echo "   • 提醒:如需保持 CHANGELOG.md 同步,请手动补一条 [${VERSION}] 记录。"
