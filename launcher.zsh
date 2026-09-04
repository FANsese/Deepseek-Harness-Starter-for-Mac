#!/bin/zsh
# ============================================================
# DeepSeek Harness Launcher - 通用 macOS 启动器主逻辑
# 设计原则：
#   1. 本启动器不打包任何 dsh 代码，首次运行从官方 npm 源安装 @deepseek-ai/dsh
#   2. 全部数据位于 ~/Library/Application Support/DeepSeekHarness
#   3. 不需要管理员权限；不写系统目录
# ============================================================
set -u

SUPPORT="$HOME/Library/Application Support/DeepSeekHarness"
CONFIG="$SUPPORT/config.env"
LOG="$SUPPORT/launcher.log"
STATUS="$SUPPORT/status.txt"        # 进度窗口数据源：百分比|主文案|详情
RUNTIME="$SUPPORT/runtime"          # 自带 Node.js 运行时（如需要自动下载）
DSH_HOME="$SUPPORT/dsh"             # dsh 内核安装位置
WORKSPACE="$SUPPORT/workspace"      # 默认 Agent 工作区
URL="http://127.0.0.1:3080"
NPM_REGISTRY="https://registry.npmmirror.com"   # 国内镜像；可改 https://registry.npmjs.org
DSH_SIZE_EST_MB=400                 # node_modules 最终大小估计（用于进度百分比）

mkdir -p "$SUPPORT"

log()  { echo "[$(date '+%F %T')] $*" >> "$LOG"; }
notify() { osascript -e "display notification \"$1\" with title \"DeepSeek Harness\"" >/dev/null 2>&1 & }
alert() { osascript -e "display dialog \"$1\" with title \"DeepSeek Harness\" buttons {\"好\"} default button 1 with icon caution" >/dev/null 2>&1 & }
set_status() { # $1=百分比 $2=主文案 $3=详情(可省)
  if [ $# -ge 3 ]; then printf '%s|%s|%s\n' "$1" "$2" "$3" > "$STATUS"; else printf '%s|%s\n' "$1" "$2" > "$STATUS"; fi
}

server_up() { curl -s -o /dev/null --max-time 2 "$URL"; }

# ---------- 单实例锁：重复双击不会起第二个安装 ----------
# 注意：必须定义在函数之后，否则锁分支调用 notify/server_up 会因未定义而崩溃
LOCK="$SUPPORT/launcher.lock"
if mkdir "$LOCK" 2>/dev/null; then
  echo $$ > "$LOCK/pid"
  trap 'rm -rf "$LOCK"' EXIT
else
  LOCK_PID=$(cat "$LOCK/pid" 2>/dev/null || echo "")
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    # 确实有另一个实例在跑
    if server_up; then
      open "$URL"
    else
      notify "DeepSeek Harness 正在启动/安装中，请看右上角进度面板，勿重复打开"
    fi
    exit 0
  else
    # 残留锁（上次崩溃/被强杀）：清理后继续执行
    rm -rf "$LOCK"
    mkdir "$LOCK" 2>/dev/null && { echo $$ > "$LOCK/pid"; trap 'rm -rf "$LOCK"' EXIT; }
    log "检测到上次残留的实例锁，已清理并继续"
  fi
fi

# ---------- 安装进度面板（AppKit 非激活面板：右上角小窗，不抢焦点） ----------
# NSPanel(Nonactivating) 不抢焦点；每秒用 NSRunLoop runUntilDate 泵事件（渲染+响应✕）；
# 点标题栏 ✕ = 取消安装；完成/崩溃/取消都会干净退出。
show_progress_window() {
  osascript - "$SUPPORT" <<'ASC' >/dev/null 2>&1 &
use AppleScript version "2.4"
use framework "AppKit"
use framework "Foundation"
use scripting additions

on run argv
  set supportDir to (item 1 of argv) as text
  set statusFile to supportDir & "/status.txt"
  set cancelFile to supportDir & "/cancel.flag"
  set pidFile to supportDir & "/launcher.lock/pid"

  set nsapp to current application's NSApplication's sharedApplication()
  nsapp's setActivationPolicy:1

  set win to current application's NSPanel's alloc()'s initWithContentRect:{{0, 0}, {300, 84}} styleMask:(1 + 2 + 128) backing:(current application's NSBackingStoreBuffered) defer:false
  win's setTitle:"DeepSeek Harness"
  win's setLevel:(current application's NSStatusWindowLevel)
  win's setHidesOnDeactivate:false

  set content to win's contentView()
  set lbl to current application's NSTextField's labelWithString:"正在准备…"
  lbl's setFrame:{{12, 50}, {276, 18}}
  set prog to current application's NSProgressIndicator's alloc()'s initWithFrame:{{12, 26}, {276, 18}}
  prog's setStyle:0
  prog's setIndeterminate:false
  prog's setMinValue:0
  prog's setMaxValue:100
  prog's setDoubleValue:1
  set detail to current application's NSTextField's labelWithString:""
  detail's setFrame:{{12, 8}, {276, 14}}
  detail's setFont:(current application's NSFont's systemFontOfSize:9)
  content's addSubview:lbl
  content's addSubview:prog
  content's addSubview:detail

  set scr to (current application's NSScreen's mainScreen()'s frame()) as list
  set scrW to item 1 of item 2 of scr
  set scrH to item 2 of item 2 of scr
  win's setFrameTopLeftPoint:{(scrW - 316), (scrH - 46)}
  win's makeKeyAndOrderFront:(missing value)

  set tick to 0
  repeat 15000 times
    -- 手动事件循环：取出并派发事件，窗口才能响应鼠标/点击/光标（runUntilDate 做不到）
    set ev to nsapp's nextEventMatchingMask:4294967295 untilDate:(current application's NSDate's dateWithTimeIntervalSinceNow:0.2) inMode:"kCFRunLoopDefaultMode" dequeue:true
    if ev is not missing value then nsapp's sendEvent:ev
    nsapp's updateWindows()
    set tick to tick + 1
    if tick mod 5 is 0 then
    set p to 0
    set msg to "正在准备…"
    set dtl to ""
    try
      set raw to do shell script "cat " & quoted form of statusFile & " 2>/dev/null"
      set AppleScript's text item delimiters to "|"
      set parts to text items of raw
      set AppleScript's text item delimiters to ""
      if (count of parts) ≥ 2 then
        set p to (item 1 of parts) as integer
        set msg to item 2 of parts
        if (count of parts) ≥ 3 then set dtl to item 3 of parts
      end if
    end try
    if p ≥ 100 then exit repeat
    -- 用户点了标题栏 ✕（面板被关闭）= 取消安装
    if (win's isVisible() as boolean) is false then
      do shell script "touch " & quoted form of cancelFile
      do shell script "kill -9 $(cat " & quoted form of pidFile & ") 2>/dev/null; pkill -f 'npm install @deepseek-ai/dsh' 2>/dev/null; true"
      exit repeat
    end if
    -- Launcher 进程已死（崩溃/被杀）→ 面板自行消失
    set alive to "1"
    try
      do shell script "kill -0 $(cat " & quoted form of pidFile & ") 2>/dev/null"
    on error
      set alive to "0"
    end try
    if alive is "0" then exit repeat
    prog's setDoubleValue:p
    lbl's setStringValue:msg
    detail's setStringValue:dtl
    end if
  end repeat
  win's orderOut:(missing value)
end run
ASC
}

# ---------- 1. 可选本地配置 ----------
# API Key 不在此处收集：dsh Web UI 首次启动自带引导填写。
# 如有需要，用户可手动创建 config.env（内容形如 DEEPSEEK_API_KEY=sk-xxx）
[ -f "$CONFIG" ] && source "$CONFIG" 2>/dev/null

# ---------- 2. 确保 Node.js >= 20.19 ----------
NODE_VER_OK() { # $1=node binary
  local v; v="$("$1" -v 2>/dev/null)" || return 1
  local major minor; major="${v#v}"; major="${major%%.*}"
  minor=$(echo "${v#v}" | awk -F. '{print $2}')
  { [ "$major" -eq 20 ] && [ "$minor" -ge 19 ]; } || [ "$major" -ge 22 ]
}

NODE_BIN=""
if [ -x "$RUNTIME/bin/node" ] && NODE_VER_OK "$RUNTIME/bin/node"; then
  NODE_BIN="$RUNTIME/bin/node"
else
  for CAND in "$(command -v node 2>/dev/null)" "/opt/homebrew/bin/node" "/usr/local/bin/node"; do
    [ -n "$CAND" ] && [ -x "$CAND" ] && NODE_VER_OK "$CAND" && NODE_BIN="$CAND" && break
  done
fi

rm -f "$STATUS" "$SUPPORT/cancel.flag"

if [ -z "$NODE_BIN" ]; then
  log "未找到 Node.js，开始自动下载官方运行时"
  show_progress_window
  set_status 8 "正在下载 Node.js 运行时（一次性，约 25MB）" "稍候，正在连接下载源…"
  ARCH=$(uname -m); [ "$ARCH" = "x86_64" ] && NARCH="x64" || NARCH="arm64"
  NODE_VER="22.23.2"   # 锁定版本，构建时人工验证过；升级请同步修改
  FNAME="node-v${NODE_VER}-darwin-${NARCH}.tar.gz"
  # 下载源：国内镜像优先，官方兜底
  SRCS=(
    "https://registry.npmmirror.com/-/binary/node/v${NODE_VER}/$FNAME"
    "https://cdn.npmmirror.com/binaries/node/v${NODE_VER}/$FNAME"
    "https://nodejs.org/dist/v${NODE_VER}/$FNAME"
  )
  mkdir -p "$RUNTIME"
  TARBALL="$SUPPORT/$FNAME"
  OK=0
  for SRC in "${SRCS[@]}"; do
    curl -fL --retry 2 --max-time 300 -o "$TARBALL" "$SRC" 2>>"$LOG" &
    CPID=$!
    # 下载进度：按已下载字节估算（包体约 25MB）
    while kill -0 "$CPID" 2>/dev/null; do
      if [ -f "$TARBALL" ]; then
        MB=$(( $(stat -f%z "$TARBALL" 2>/dev/null || echo 0) / 1048576 ))
        [ "$MB" -gt 26 ] && MB=26
        set_status $(( 8 + MB * 22 / 26 )) "正在下载 Node.js 运行时" "已下载 ${MB}MB / 约26MB · 源: $(echo "$SRC" | cut -d/ -f3)"
      fi
      sleep 1
    done
    wait "$CPID" && { OK=1; break; } || rm -f "$TARBALL"
  done
  [ "$OK" = "1" ] || { set_status 100 "done"; alert "Node.js 下载失败，请检查网络后重试。\n日志：$LOG"; exit 1; }
  set_status 32 "正在解压 Node.js 运行时…" ""
  tar -xzf "$TARBALL" -C "$RUNTIME" --strip-components 1 && rm -f "$TARBALL"
  NODE_BIN="$RUNTIME/bin/node"
  NODE_VER_OK "$NODE_BIN" || { set_status 100 "done"; alert "Node 运行时异常，请查看日志：$LOG"; exit 1; }
  log "Node 运行时就绪: $($NODE_BIN -v)"
fi
NPM_BIN="$(dirname "$NODE_BIN")/npm"

# 关键修复：npm 是 `#!/usr/bin/env node` 脚本，GUI 启动时 PATH 为空，
# 必须把运行时的 bin 目录加进 PATH，否则报 `env: node: No such file or directory`
export PATH="$(dirname "$NODE_BIN"):$PATH"
log "使用 Node: $NODE_BIN ($($NODE_BIN -v 2>/dev/null))"

# ---------- 3. 确保 dsh 内核（官方 npm 源） ----------
DSH_ENTRY="$DSH_HOME/node_modules/@deepseek-ai/dsh/lib/bin.js"
if [ ! -f "$DSH_ENTRY" ]; then
  [ -f "$STATUS" ] || show_progress_window   # 若已过下载阶段则补开窗口
  log "首次运行，从官方 npm 安装 @deepseek-ai/dsh"
  set_status 36 "正在安装官方内核 @deepseek-ai/dsh" "连接 npm 源…（首次约需 5–12 分钟，只此一次）"
  notify "正在安装 DeepSeek Harness 内核，可看进度窗口"
  mkdir -p "$DSH_HOME"
  cd "$DSH_HOME" || exit 1
  [ -f package.json ] || "$NPM_BIN" init -y >/dev/null 2>&1
  # 关键：npm 解析 dsh 依赖树需要更大堆内存（官方依赖较多，小内存 Mac 默认会 OOM）
  export NODE_OPTIONS="--max-old-space-size=4096"
  "$NPM_BIN" install @deepseek-ai/dsh --registry="$NPM_REGISTRY" --no-audit --no-fund --loglevel=warn >> "$LOG" 2>&1 &
  NPMPID=$!
  # 实时进度：轮询 node_modules 体积与包数量
  # 注意：npm 解析依赖阶段可能持续 5-15 分钟且不写任何文件，此阶段用
  # "已等待时间 + npm 缓存体积"证明进程存活（缓存持续增长即在工作）
  INSTALL_START=$SECONDS
  while kill -0 "$NPMPID" 2>/dev/null; do
    SIZE_KB=$(du -sk "$DSH_HOME/node_modules" 2>/dev/null | cut -f1)
    MB=$(( SIZE_KB / 1024 ))
    ELAPSED=$(( SECONDS - INSTALL_START ))
    if [ "$MB" -ge 1 ]; then
      PKGS=$(find "$DSH_HOME/node_modules" -maxdepth 2 -name package.json 2>/dev/null | wc -l | tr -d ' ')
      PCT=$(( 36 + MB * 58 / DSH_SIZE_EST_MB )); [ "$PCT" -gt 94 ] && PCT=94
      set_status "$PCT" "正在安装官方内核 @deepseek-ai/dsh" "已写入 ${MB}MB / 约${DSH_SIZE_EST_MB}MB · ${PKGS} 个包 · 已进行 ${ELAPSED} 秒"
    else
      # 缓存已满时体积不再增长，改以 npm 调试日志行数作为"仍在干活"的证据
      NPM_LOG=$(ls -t "$HOME/.npm/_logs"/*.log 2>/dev/null | head -1)
      LINES=$(wc -l < "$NPM_LOG" 2>/dev/null | tr -d ' ')
      PCT=$(( 36 + ELAPSED / 12 )); [ "$PCT" -gt 60 ] && PCT=60
      set_status "$PCT" "正在解析依赖包（不写盘、不下载，属正常，最长约 20 分钟）" "已等待 ${ELAPSED} 秒 · 依赖表已解析 ${LINES} 项"
    fi
    sleep 2
  done
  wait "$NPMPID"; NPM_EXIT=$?
  log "npm install 退出码: $NPM_EXIT"
  if [ -f "$SUPPORT/cancel.flag" ]; then
    log "用户取消了安装，静默退出"
    rm -f "$SUPPORT/cancel.flag"
    exit 0
  fi
  if [ "$NPM_EXIT" -ne 0 ]; then
    set_status 100 "done"
    alert "内核安装失败（退出码 $NPM_EXIT），请检查网络后重新打开本应用，会自动续装。\n详细日志：$LOG"
    exit 1
  fi
  [ -f "$DSH_ENTRY" ] || { set_status 100 "done"; alert "安装结果异常，请查看日志：$LOG"; exit 1; }
  log "dsh 内核安装完成"
  set_status 96 "内核安装完成，正在启动服务…" ""
  notify "内核安装完成，正在启动"
fi

# ---------- 4. 启动 / 打开 ----------
if server_up; then
  set_status 100 "done"
  open "$URL"
  exit 0
fi

mkdir -p "$WORKSPACE"
export NODE_OPTIONS="--max-old-space-size=4096"
export DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-}"
cd "$WORKSPACE" || exit 1

log "启动 dsh web"
"$NODE_BIN" "$DSH_ENTRY" web --no-open >> "$LOG" 2>&1 &
PID=$!
disown

for i in {1..30}; do
  sleep 1
  if server_up; then
    set_status 100 "done"
    open "$URL"
    log "服务已就绪"
    break
  fi
  kill -0 "$PID" 2>/dev/null || {
    set_status 100 "done"
    alert "dsh 启动失败，请查看日志：$LOG"
    exit 1
  }
done

# 保持进程守护；dsh 退出则 Launcher 退出
wait "$PID"
