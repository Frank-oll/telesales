#!/bin/bash
# Telesales 解锁助手
# 作用:移除 macOS 给"从网上下载的文件"打的隔离标记,
# 让你能直接双击打开 Telesales,无需进入"系统设置"或手敲终端命令。
# 用法:双击本文件即可;如被拦("无法验证开发者"),右键点本文件 → 打开。

clear

cat <<'BANNER'
==========================================
            Telesales 解锁助手
==========================================

  作用:让 macOS 信任 Telesales,以后双击
        就能直接打开,不再弹"无法验证开发者"。

  开始前请确认:已把 Telesales 拖到了
  「应用程序(Applications)」文件夹。

  请按【回车键】开始。

BANNER

read -r

APP="/Applications/Telesales.app"

if [ ! -d "$APP" ]; then
  echo ""
  echo "[未找到 App]"
  echo ""
  echo "请先完成下面这一步,然后再次双击本脚本:"
  echo "  1. 回到 dmg 窗口"
  echo "  2. 把左上角的 Telesales 图标拖到右上角的 Applications 文件夹"
  echo "  3. 再回来双击本「解锁并打开 Telesales」"
  echo ""
  read -n 1 -s -r -p "按任意键关闭本窗口"
  echo ""
  exit 1
fi

echo ""
echo "找到应用,正在解锁..."
echo ""

if xattr -dr com.apple.quarantine "$APP" 2>/dev/null; then
  echo "[完成] 解锁成功,正在打开 Telesales..."
  open "$APP"
  echo ""
  echo "如果 Telesales 没有自动弹出,去【启动台】或【应用程序】里双击它即可。"
else
  echo "[需要密码] 需要管理员权限才能解锁。请输入你的开机密码:"
  echo "          (屏幕不会显示字符,这是正常的,输完按回车)"
  echo ""
  if sudo xattr -dr com.apple.quarantine "$APP"; then
    echo ""
    echo "[完成] 解锁成功,正在打开 Telesales..."
    open "$APP"
  else
    echo ""
    echo "[失败] 解锁失败。"
    echo "       请把本窗口截图发给作者,以便排查。"
  fi
fi

echo ""
read -n 1 -s -r -p "按任意键关闭本窗口"
echo ""
