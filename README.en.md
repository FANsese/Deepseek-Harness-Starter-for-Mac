# DeepSeek Harness Launcher for macOS

> **English | [中文](README.md)**

A **clean**, double-click launcher for DeepSeek Harness (`dsh`), built for people who do not want to touch a terminal.

> **This launcher contains, modifies or repackages NO dsh code whatsoever.**
> On first launch it installs the official `@deepseek-ai/dsh` package from the **official npm registry** — everyone gets the exact same official kernel you would get by running the official commands yourself. The launcher itself is an open-source shell script, fully readable and auditable.

> 🌏 **Language note:** All launcher UI and install-flow prompts are currently in **Chinese** (no localization yet). The underlying product (DeepSeek Harness) is a web UI and follows its own language.

## Why this exists

- DeepSeek Harness is officially distributed as a CLI / `npx` tool, which is unfriendly to non-developers
- Third-party `.exe` / `.dmg` installers circulating online have unknown origins and may be tampered with
- A plain `npm install` of dsh can crash on low-RAM Macs due to Node's default heap limit (this launcher has a built-in fix)

## Features

- ✅ Double-click to launch the Web UI (`http://127.0.0.1:3080`) and auto-open the browser
- ✅ Your DeepSeek API Key is entered through the official dsh Web UI onboarding — the launcher never collects or touches it
- ✅ Auto-detects system Node.js (including Homebrew paths); if missing, auto-downloads the official Node 22 runtime into your user directory (**no admin password required**, auto-adapts to Apple Silicon / Intel)
- ✅ Installs the official dsh kernel from the npm registry (automatically uses the npmmirror mirror for faster access from China)
- ✅ Bundled large-heap settings fix the OOM crash when installing on 8GB-RAM Macs
- ✅ A small, **focus-friendly progress panel** sits in the top-right corner (non-activating, never steals focus, shows live progress, ✕ to abort cleanly)
- ✅ Single-instance with **stale-lock self-healing**: double-clicks never conflict; after a crash/force-quit, just double-click again to resume
- ✅ Process guardian: the service keeps running even after the browser tab is closed
- ✅ Full logging for troubleshooting

## Installation (end users)

> Chinese step-by-step guide: [使用说明.md](使用说明.md)

1. Download `DeepSeek-Harness-Launcher-macOS.zip` and unzip
2. Drag `DeepSeek Harness.app` into the Applications folder (anywhere works)
3. **First launch**: right-click the app → "Open" → "Open" again (not notarized, so macOS asks once; normal double-click works afterwards)
   - If it says "damaged", run in Terminal: `xattr -cr "/Applications/DeepSeek Harness.app"`
4. Wait for the automatic install (**5–30 minutes on first run**, depends on network). The progress panel shows live status; ✕ aborts anytime. When done, the browser opens the Harness UI, where you fill in your DeepSeek API Key ([platform.deepseek.com](https://platform.deepseek.com), requires a top-up)

## Where data lives

Everything is under `~/Library/Application Support/DeepSeekHarness/`:

| Path | Contents |
|---|---|
| `config.env` | Optional manual config (e.g. `DEEPSEEK_API_KEY=sk-xxx`); skip it and fill in the web UI if you prefer |
| `dsh/` | Official dsh kernel (installed via npm) |
| `runtime/` | Auto-downloaded Node runtime (only present when no system Node exists) |
| `workspace/` | Agent's default working directory (changeable in the web UI) |
| `launcher.log` | Runtime log (look here first when troubleshooting) |
| `status.txt` | Live status feed of the progress panel (`percent\|message\|detail`) |

**Full uninstall**: delete the app and that folder — no leftovers.

## Security notes

- The Web UI listens on `127.0.0.1` only and is unreachable from LAN/public networks; **never expose it via port forwarding** (dsh's Web UI has no login)
- The API key is entered through the official dsh UI and stored locally; the launcher never uploads anything
- To use the official npmjs registry instead of the mirror, edit the `NPM_REGISTRY` variable in the launcher script

## FAQ

**Q: First install is slow / fails?**
Check `launcher.log`. Failures usually happen on flaky networks; just double-click the app again and it resumes automatically.

**Q: I already installed dsh via CLI. Can I still use this?**
Yes — the launcher maintains its own independent copy (no interference).

**Q: How do I upgrade the dsh kernel?**
```sh
cd ~/Library/Application\ Support/DeepSeekHarness/dsh
npm update @deepseek-ai/dsh
```
(dsh is in official developer preview — upgrades may break things.)

**Q: Auto-start at login?**
System Settings → General → Login Items & Extensions → add the app.

## For developers: build it yourself

```sh
git clone <this repo>
cd <repo root>
./build.sh        # produces dist/DeepSeek Harness.app and the release zip
```

Requires macOS 12+. The build script only assembles files and applies an ad-hoc signature — no other dependencies.

To debug the progress panel without waiting for a real install: `./panel-test.sh`

## Disclaimer

- Community third-party launcher, **not affiliated with or endorsed by DeepSeek AI**
- The dsh kernel belongs to DeepSeek AI (MIT License); this launcher is open-source under the MIT License
- The kernel version tracks the latest official npm release
