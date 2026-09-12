# Ali Matrix · 新人第一天

GitHub Pages 直接提供 `index.html`，没有构建步骤或运行时依赖。

**这是公开仓库**：只放通用步骤和公司名，不放群邀请链接、个人账号、内部地址、密钥或配置变量。改动走 PR。

## 页面结构

- `index.html`：三阶段、11 步入门，以及工具箱、Telegram、Teleport、命令和求助说明。
- `styles.css`：桌面 / 手机布局、深色模式、键盘焦点、减少动态效果和打印样式。
- `app.js`：步骤导航、完成确认、审批等待、安装前置检查、系统切换、进度保存和命令复制。
- `img/`：现有截图、示意图与图标。截图仅作位置参考，安装版本以官网为准。

Telegram 在入群前准备；Claude Code、Codex CLI 和 Codex Desktop 纳入主流程。Teleport 尚未上线，说明放在工具箱，暂不计入完成进度。上线后再补公司批准的连接方式和版本，公开页不写内部入口。

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
