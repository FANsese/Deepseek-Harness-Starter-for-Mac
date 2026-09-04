#!/bin/zsh
# 面板快速自测工具（开发用，不打包进 App）
# 用途：不必等真实安装，几秒内就能看到进度面板，测试鼠标悬停 / ✕ 点击是否正常。
# 用法: ./panel-test.sh
# 结束方式：点面板标题栏的 ✕，或按 Ctrl+C 结束本脚本。
set -u
cd "$(dirname "$0")"

TMP="${TMPDIR:-/tmp/}dsh-panel-test"
rm -rf "$TMP"; mkdir -p "$TMP/launcher.lock"

# 假 launcher 进程：让面板的"存活检测"通过
( sleep 900 & echo $! > "$TMP/launcher.lock/pid" )
FAKE_PID=$(cat "$TMP/launcher.lock/pid")

# 从 launcher.zsh 提取面板脚本
sed -n '/osascript - "\$SUPPORT"/,/^ASC$/p' launcher.zsh | sed '1d;$d' > "$TMP/panel.applescript"

printf '42|正在解析依赖包（不写盘、不下载，属正常）|已等待 300 秒 · 依赖表已解析 512 项\n' > "$TMP/status.txt"

echo "面板已启动（右上角小窗）。请测试："
echo "  1) 鼠标悬停到面板上 —— 是否出现沙滩球/转圈"
echo "  2) 点标题栏 ✕     —— 面板是否立刻消失"
echo "模拟进度在跑，30 秒后自动结束；或点 ✕ 立即结束。"
echo "取消标记写入位置: $TMP/cancel.flag"

osascript "$TMP/panel.applescript" "$TMP" &
PANEL=$!

# 模拟进展
for i in {1..10}; do
  sleep 3
  kill -0 "$PANEL" 2>/dev/null || break
  printf '%d|正在安装官方内核 @deepseek-ai/dsh|已写入 %dMB / 约400MB · %d 个包\n' $((42 + i * 5)) $((i * 40)) $((i * 45)) > "$TMP/status.txt"
done

if [ -f "$TMP/cancel.flag" ]; then
  echo "✅ 取消标记已写入 —— ✕ 点击被正确捕获，取消逻辑正常"
else
  echo "ℹ️  未检测到取消标记（可能是测试跑完自动结束，或 ✕ 没点成功）"
fi

kill "$PANEL" 2>/dev/null
kill "$FAKE_PID" 2>/dev/null
echo "测试结束"
