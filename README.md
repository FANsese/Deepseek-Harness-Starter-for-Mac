# DeepSeek Harness Launcher for macOS

一个**干净的** DeepSeek Harness（`dsh`）图形化启动器：双击图标即用，使得使用体验更加便捷顺利。

> **本启动器不包含、不修改、不重新打包任何 dsh 代码。**
> 首次运行时，它会从**官方 npm 源**安装 `@deepseek-ai/dsh` 官方包——每个人拿到的都是 DeepSeek 官方原版内核，与手动执行官方安装命令完全一致。启动器本身只是一个约 150 行的开源 shell 脚本，逻辑全部可读、可审计。

## 为什么需要它

- DeepSeek Harness 官方目前以命令行 / `npx` 方式启动，对非开发者不友好
- 网上流传的各种第三方 exe / dmg 安装包来源不明，存在被篡改风险
- `npm install` 安装 dsh 时在小内存 Mac 上会因 Node 默认堆内存不足而崩溃（本启动器已内置修复）
- 如果mac也能像Windows一样能双击运行某个指令那也不用那么麻烦了捏（）

## 功能

- ✅ 双击启动 Web UI（`http://127.0.0.1:3080`）并自动打开浏览器
- ✅ API Key 交给 dsh Web UI 自带的首次引导填写，启动器不收集、不经手
- ✅ 自动探测系统 Node.js（含 Homebrew 路径）；没有则自动下载官方 Node 22 运行时到用户目录（**无需管理员密码**，Apple Silicon / Intel 双架构自适应）
- ✅ 自动从官方 npm 安装 dsh 内核（国内网络自动走 npmmirror 镜像，加速且防超时）
- ✅ 内置大堆内存参数，修复 8GB 内存 Mac 安装时 OOM 崩溃
- ✅ 进程守护：关掉浏览器服务仍在，重复点击图标不会起多个服务
- ✅ 全程日志可查，出问题能定位

## 安装

1. 下载 `DeepSeek-Harness-Launcher-macOS.zip`，解压
2. 把 `DeepSeek Harness.app` 拖入「应用程序」文件夹
3. **首次打开**：右键点击 App → 「打开」→ 再点「打开」（因为未做付费公证，macOS 会拦一次；此后可正常双击）
   - 若提示"已损坏"，在终端执行：`xattr -cr "/Applications/DeepSeek Harness.app"`
4. 等待首次安装（实际约 5–20 分钟：依赖解析阶段不写盘属正常，进度对话框会显示实时状态；只此一次）。期间屏幕右上角有一个不抢焦点的小进度面板，点其标题栏 ✕ 可随时中止安装。完成后浏览器自动打开 Harness 界面，按页面引导填入 DeepSeek API Key（[platform.deepseek.com](https://platform.deepseek.com) 创建，需充值）

## 数据都存在哪

全部位于 `~/Library/Application Support/DeepSeekHarness/`：

| 路径 | 内容 |
|---|---|
| `config.env` | 可选手动配置（如 `DEEPSEEK_API_KEY=sk-xxx`，也可不建、直接在网页里填） |
| `dsh/` | 官方 dsh 内核（npm 安装） |
| `runtime/` | 自动下载的 Node 运行时（仅系统无 Node 时存在） |
| `workspace/` | Agent 默认工作区（Agent 只能动这里，可在网页中改） |
| `launcher.log` | 运行日志（排查问题先看它） |

**完全卸载**：删掉 App 和上面整个文件夹即可，不留任何残余。

## 安全说明

- Web UI 仅监听本机 `127.0.0.1`，局域网/公网无法访问；**请勿用端口转发等方式暴露到公网**（dsh Web UI 无登录鉴权）
- API Key 由 dsh Web UI 引导填写并保存在本机，启动器不做任何网络上传；也可通过 `config.env` 提供
- 想改用官方 npmjs 源：编辑启动器脚本里的 `NPM_REGISTRY` 变量

## 常见问题

**Q: 首次安装很慢 / 失败？**
看 `launcher.log`。国内网络一般走 npmmirror 镜像没问题；失败后重新双击 App 会自动重试。

**Q: 已经用命令行装过 dsh 了，还能用这个吗？**
可以，但启动器会维护自己独立的一套（互不干扰）。也可以手动把已有的 `node_modules` 拷到数据目录的 `dsh/` 下跳过安装。

**Q: 如何升级 dsh 内核？**
终端执行：
```sh
cd ~/Library/Application\ Support/DeepSeekHarness/dsh
npm update @deepseek-ai/dsh
```
（dsh 处于官方开发者预览期，升级后可能有破坏性变更。）

**Q: 想开机自启？**
系统设置 → 通用 → 登录项与扩展 → 添加本 App。

## 自己构建

```sh
git clone <本仓库>
cd dsh-launcher
./build.sh   # 产出 dist/DeepSeek Harness.app 与发布 zip
```

需要 macOS 12+。构建脚本只做文件组装 + ad-hoc 签名，无其他依赖。

## 声明

- 本项目为社区第三方启动器，与 DeepSeek 官方无隶属关系
- dsh 内核版权归 DeepSeek AI 所有（MIT License），本启动器亦以 MIT 协议开源
- 内核版本跟随官方 npm 最新发布
