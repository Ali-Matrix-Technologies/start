# Ali Matrix · 新人第一天

GitHub Pages 直接提供 `index.html`，没有构建步骤或运行时依赖。

**这是公开仓库**：只放通用步骤和公司名，不放群邀请链接、个人账号、内部地址、密钥或配置变量。改动走 PR。

## 页面结构

- `index.html`：三阶段、11 步入门，以及工具箱、Telegram、Teleport、命令和求助说明。`#project-work` 衔接工作台内 clone-project / issue-flow SOP，说明独立 worktree 与交付清理；不新增入职勾选项。
- `styles.css`：桌面 / 手机布局、深色模式、键盘焦点、减少动态效果和打印样式。
- `app.js`：步骤导航、完成确认、审批等待、安装前置检查、系统切换、进度保存和命令复制。
- `img/`：现有截图、示意图与图标。截图仅作位置参考，安装版本以官网为准。
- `scripts/install-tools.sh` / `install-tools.ps1`：公开新人工具脚本，页面 s2 推荐复制一次安装；s5 / s9 先验版本，缺失时按单工具范围安装。手动步骤保留在折叠区。

## 新人工具脚本

默认准备 Git、Node.js、gh、Claude Code、Codex CLI，逐项检测、安装和验证。Node 低于 22 或 npm/npx 缺失需要处理；新装使用 LTS。已就绪工具跳过，失败停在当前项，不能把检查失败视作完成。`--only base|claude|codex|all`（Windows `-Only`）可缩小范围；Codex 包含 Node 依赖，Windows Claude 包含 Git 依赖。`--check` / `-Check` 仅核对当前终端命令，不联网、不安装、不写配置。

- macOS：x64 / ARM64，bash / zsh；Git/gh 走 Homebrew，新装 Homebrew 要 macOS 15+，按官方提示完成系统确认。Node 按需用 nvm 安装 LTS。
- Linux：Ubuntu 22.04+ / Debian 12+，x64 / ARM64，bash / zsh，有 sudo；页面在缺 curl 时提供准备命令。Git 用 apt，gh 用官方 signed-by 源，Node 用 nvm。
- Windows：x64 / ARM64，PowerShell 5.1+ 与 WinGet；基础工具与 Claude 用精确 WinGet 包，Codex 用 npm.cmd。缺 WinGet 提示安装 Microsoft Store「应用安装程序」。非零安装码（包括需要重启）停止；旧 Node 若不由 WinGet 管理，按错误提示用官方 LTS 安装包更新。

脚本可能按需安装 Homebrew/nvm、设置默认 Node LTS、追加 shell 命令路径、添加官方 gh apt 源及 Windows 用户 npm PATH，不覆盖 shell 文件、不永久修改 PowerShell 执行策略、不使用 sudo npm、不操作 Git 身份/登录/组织邀请。全新 macOS 缺少 Apple Command Line Tools 时，会打开系统安装提示并停止；安装完成后重跑继续。下载先落到唯一临时文件，成功且非空后才执行并在退出时清理。工具未成功验证时不输出安装完成。安装完成后重开终端复验，然后继续 GitHub/Claude/ChatGPT 登录、桌面应用和公司 SOP，浏览器不自动勾选。

本地验证只运行 `bash scripts/install-tools.sh --check`，不能为了测试卸载真实工具。行为回归用隔离目录和命令 mock：

```sh
bash -n scripts/install-tools.sh
python3 tests/install-tools.py
```

Windows 用 `powershell -NoProfile -File tests/install-tools.ps1`。CI 覆盖 macOS/Ubuntu Bash 与 Windows PowerShell 5.1；这些是控制流测试，不等同于全新电脑实装。发布时先验证 Pages 的两个脚本返回正确内容，再发布引用它们的公司 SOP。回滚用 revert PR 恢复原手动入口；不自动卸载新人已安装的工具。

脚本安装依据：[Homebrew](https://docs.brew.sh/Installation)、[nvm](https://github.com/nvm-sh/nvm#install--update-script)、[GitHub CLI apt](https://github.com/cli/cli/blob/trunk/docs/install_linux.md)、[Claude Code](https://code.claude.com/docs/en/setup)、[Codex CLI](https://learn.chatgpt.com/docs/codex/cli)、[Codex npm 安装](https://learn.chatgpt.com/docs/security/plugin/code-changes)、[WinGet](https://learn.microsoft.com/en-us/windows/package-manager/winget/install)。

Telegram 群目前仅保留「求助」和「公告」两个入口；入职绑定从 Morpheus 私聊开始，由引路人提供 bot 名片或私聊入口；权限申请、已有权限和进度在「我的工作台 → 权限与申请」里完成，私聊命令仅作兼容入口。Telegram 在入群前准备；Claude Code、Codex CLI 和 Codex Desktop 纳入主流程。Teleport 尚未上线，说明放在工具箱，暂不计入完成进度。上线后再补公司批准的连接方式和版本，公开页不写内部入口。

原有 `s0`–`s8` 锚点与 `ali-start-v1` 存储键保留。新增 `s9` / `s10` 用于 Codex；旧版的公司插件安装与首次对话需要重新确认，确保同时检查两种 AI 工具。其他已完成步骤保留。浏览器中的勾选仅为个人记录，实际入职状态以 Telegram bot 为准。

## 本地预览与检查

```sh
python3 -m http.server 8765 --bind 127.0.0.1
```

打开 http://127.0.0.1:8765 。提交前执行：

```sh
python3 scripts/check.py
node --check app.js
```

浏览器回归检查使用 Playwright，仅用于开发，不是网站依赖：

```sh
uv run --with playwright python tests/browser.py
```

默认使用已安装的 Chrome；无 Chrome 时先安装 Playwright Chromium，并设置 `BROWSER_CHANNEL=chromium`。测试会自行启动本地服务器，覆盖入门、等待审批、进度迁移、系统选择、复制降级、移动端、无脚本和本地存储不可用场景。

安装说明来源：[Telegram](https://telegram.org/apps)、[GitHub CLI](https://cli.github.com/manual/gh_auth_login)、[Node.js](https://nodejs.org/en/download)、[Claude Code](https://code.claude.com/docs/en/setup)、[Codex CLI](https://developers.openai.com/codex/cli/)、[Codex 桌面应用](https://developers.openai.com/codex/app/)、[Teleport Connect](https://goteleport.com/docs/connect-your-client/teleport-clients/teleport-connect/)。
