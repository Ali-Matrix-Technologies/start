# 新人第一天

你好，欢迎加入 Ali Matrix。这一页是你在拥有任何账号之前唯一需要看的东西。按顺序做，每一步都有"怎么确认做对了"和"不行找谁"。全部做完大约 1 到 2 小时，做完之后你就有一个 AI 助手带着你做后面的所有事，不需要再找人教。

> 你不需要会编程，也不需要用过 AI。看不懂的词，页面最下面有解释。

## 第 0 步：准备

- 一台自己的电脑，macOS、Windows、Linux 都行。
- 一个能收邮件的邮箱，用哪个邮箱注册各种账号，以拉你进群的同事告诉你的为准。
- 能正常打开 github.com 和 claude.ai 的网络。打不开先别自己折腾，问拉你进群的同事拿公司的网络方案。
- 手机上装一个验证器应用，比如 Google Authenticator 或 1Password，后面开两步验证要用。

**不行找谁**：拉你进群的那位同事，本页下面统称"你的引路人"。

## 第 1 步：注册 GitHub

GitHub 是放代码和流程记录的网站，也是公司的"身份系统"：你能看什么、改什么，由它决定。

1. 打开 https://github.com/signup ，用第 0 步的邮箱注册。
2. 注册完打开 https://github.com/settings/security ，开启 Two-factor authentication，选验证器应用，把恢复码保存到密码管理器或安全的地方。**公司组织强制两步验证，不开的话后面加不进来。**
3. 记住你的 GitHub 用户名，后面要报给 bot。

**怎么确认**：登录 https://github.com/settings/security 看到两步验证已开启。

## 第 2 步：装三个基础工具

终端是用文字命令操控电脑的窗口，AI 助手就住在里面。要装的三个工具：git 记录代码修改，Node.js 运行一些工具，gh 让终端能操作 GitHub。

**macOS**
1. 打开"终端"应用（聚焦搜索里输入 终端）。
2. 装 Homebrew：复制下面整行到终端，回车，按提示输密码（输入时不显示，正常）。
   ```
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
   装完它会打印两行让你复制执行的命令，照做。
3. 装工具：
   ```
   brew install git node gh
   ```

**Windows**
1. 开始菜单搜索 PowerShell，右键"以管理员身份运行"。
2. 依次执行三行：
   ```
   winget install --id Git.Git -e
   winget install --id OpenJS.NodeJS.LTS -e
   winget install --id GitHub.cli -e
   ```

**Linux（Ubuntu / Debian）**
1. 打开终端，执行：
   ```
   sudo apt update && sudo apt install -y git curl
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
   ```
2. 关掉终端重新打开，执行 `nvm install --lts`。
3. gh 按官方说明安装：https://github.com/cli/cli/blob/trunk/docs/install_linux.md

**怎么确认**：**关掉终端，重新打开一个**（这一步不做，下面的命令会说找不到），执行：
```
git --version && node --version && gh --version
```
三行都打印出版本号，node 的版本号 v18 以上。

**常见问题**：提示 command not found，九成是没重开终端。

## 第 3 步：让终端登录 GitHub

```
gh auth login -h github.com -p ssh -w
```
一路选默认：GitHub.com、SSH、Yes 生成密钥、浏览器登录。登录完再执行：
```
gh auth setup-git
```

**怎么确认**：`gh auth status` 显示 Logged in to github.com。

## 第 4 步：注册 Claude 并订阅

Claude Code 是我们主要用的 AI 助手，第一天只装这一个。它需要一个 Claude 账号，费用你先付，公司报销，报销流程进群后 AI 会告诉你。

1. 打开 https://claude.ai 用第 0 步的邮箱注册。
2. 进 Settings → Billing 订阅 Pro（日常够用）或 Max（重度写代码）。
3. 账单在同一页能下载，留着报销。

**怎么确认**：Billing 页显示订阅生效。

## 第 5 步：装 Claude Code 并登录

macOS / Linux 终端：
```
curl -fsSL https://claude.ai/install.sh | bash
```
Windows PowerShell：
```
irm https://claude.ai/install.ps1 | iex
```
关掉终端重新打开，执行 `claude`，按提示在浏览器登录，回到终端看到对话框就成了。

**怎么确认**：终端里 `claude --version` 打印版本号。

## 第 6 步：进群，绑定，等审批

1. 让你的引路人把你拉进公司 Telegram 群。进群后一个叫 Morpheus 的 bot 会 @你，给你一个"开始入职"按钮。
2. 点按钮进入和 Morpheus 的私聊，发 `/start`。它会给你一个 GitHub 设备码链接：浏览器打开、输入代码、用你第 1 步的 GitHub 账号授权，回来点"我已授权"。
3. 管理员在群里点一下批准，你会收到 GitHub 组织的邀请，去 https://github.com/orgs/Ali-Matrix-Technologies/invitation 接受。
4. 私聊里点左下角菜单"入门看板"，能看到你走到哪一步了。

**怎么确认**：Morpheus 私聊你"已接受邀请，入职单完成"。

## 第 7 步：一条命令接入公司流程

终端执行：
```
npx github:Ali-Matrix-Technologies/sop
```
问 Ok to proceed 就按 y。它会检查前面几步、把公司流程库拉到本机、给 Claude Code 装上引导技能。

**怎么确认**：最后打印"完成"。

## 第 8 步：对 AI 说第一句话

终端执行 `claude` 进入对话，输入：

```
我是新人，从哪开始
```

它会列出公司的所有流程，并带你一步步做。之后遇到任何"这里怎么做"，先问它，再问人。它会问你"要不要我带你做"，说要。

**从此以后**：卡住了在群里的"求助"话题发消息；想申请权限私聊 Morpheus 发 `/request`；想看流程发 `/sops`。

## 这些词是什么

- **终端**：只有文字的窗口，你打命令它执行。
- **Git**：代码的修改历史记录本。**GitHub**：把记录放到网上共享的网站，也是我们的身份系统。
- **两步验证（2FA）**：登录时除密码外再验一次手机验证器，公司强制。
- **Node.js**：一个运行环境，很多工具靠它跑；**npx**：用一条命令临时运行一个工具。
- **gh**：GitHub 的命令行工具，让终端能登录和操作 GitHub。
- **Claude Code / Codex**：住在终端里的 AI 编程助手，你说要什么，它动手并解释。
- **SOP**：公司里"这件事怎么做"的标准流程，每条都有 AI 能执行的版本。
- **Morpheus**：公司 Telegram 群里的 bot，负责入职、申请权限、查流程。
- **Teleport**：以后访问服务器和数据库的统一大门，现在还没上线。
