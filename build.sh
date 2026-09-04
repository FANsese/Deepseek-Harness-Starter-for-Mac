#!/bin/zsh
# DeepSeek Harness Launcher - 一键构建脚本
# 用法: ./build.sh   （在本目录执行，产出 dist/"DeepSeek Harness.app" 与 zip）
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="DeepSeek Harness"
APP="dist/$APP_NAME.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp launcher.zsh "$APP/Contents/MacOS/DeepSeekHarness"
chmod +x "$APP/Contents/MacOS/DeepSeekHarness"
cp Info.plist "$APP/Contents/Info.plist"

# 图标：优先使用本地已有的 AppIcon.icns，否则从已安装的同名 App 复制，再否则不带图标
if [ -f AppIcon.icns ]; then
  cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
elif [ -f "$HOME/Applications/$APP_NAME.app/Contents/Resources/AppIcon.icns" ]; then
  cp "$HOME/Applications/$APP_NAME.app/Contents/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
else
  echo "警告：未找到 AppIcon.icns，本次构建将没有图标"
fi

# 广 quarantine 属性（本机构建无），并做 ad-hoc 签名减少"已损坏"提示
xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep -s - "$APP" 2>/dev/null || true

cd dist
rm -f "DeepSeek-Harness-Launcher-macOS.zip"
zip -qry "DeepSeek-Harness-Launcher-macOS.zip" "$APP_NAME.app"
echo "构建完成: dist/$APP_NAME.app"
echo "发布包:   dist/DeepSeek-Harness-Launcher-macOS.zip"
