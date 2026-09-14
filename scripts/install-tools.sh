#!/usr/bin/env bash
# Ali Matrix newcomer tools. Source URLs and supported platforms: ../README.md
# Run with bash (including macOS Bash 3.2); --check never installs or writes.
set -Eeuo pipefail

install_home="${HOME:?HOME is required}"
install_tmp=''
install_step='准备'
install_only=all
install_check=0

say() { printf '%s\n' "$*"; }
fail() { say "✘ $*" >&2; return 1; }
cleanup() {
  if [[ -n "$install_tmp" && -d "$install_tmp" ]]; then
    # Only files created by this invocation, never a user directory.
    rm -f "$install_tmp/download" "$install_tmp/github-cli.list"
    rmdir "$install_tmp"
  fi
}
on_error() {
  local code=$?
  say "✘ 未完成：${install_step}。修复上方错误后重跑；已验证的工具会跳过。" >&2
  say '若提示找不到命令，先关闭并重开终端。不要给 npm 安装命令加 sudo。' >&2
  exit "$code"
}
tool_ready() {
  local tool=$1 value major
  value=$("$tool" --version 2>/dev/null) || return 1
  [[ -n "$value" ]] || return 1
  if [[ "$tool" == node ]]; then
    [[ "$value" =~ ^v?([0-9]+)\. ]] || return 1
    major=${BASH_REMATCH[1]}
    (( major >= 22 )) || return 1
    npm --version >/dev/null 2>&1 && npx --version >/dev/null 2>&1 || return 1
  fi
}
platform() {
  install_os=$(uname -s)
  case "$(uname -m)" in arm64|aarch64|x86_64) ;; *) fail '仅支持 x64 / ARM64 电脑，请使用页面手动安装。'; return 1 ;; esac
  case "$install_os" in
    Darwin) ;;
    Linux)
      [[ -r /etc/os-release ]] || { fail '无法识别 Linux，请使用手动安装。'; return 1; }
      # Standard OS metadata, not remote content.
      . /etc/os-release
      case "${ID:-}:${VERSION_ID:-}" in
        ubuntu:*) [[ ${VERSION_ID%%.*} -ge 22 ]] || return 1 ;;
        debian:*) [[ ${VERSION_ID%%.*} -ge 12 ]] || return 1 ;;
        *) fail '自动安装支持 Ubuntu 22.04+ / Debian 12+；其他发行版请使用手动步骤。'; return 1 ;;
      esac ;;
    *) fail '此脚本支持 macOS / Ubuntu / Debian；Windows 请使用 PowerShell 版本。'; return 1 ;;
  esac
}
profile_line() {
  local line=$1 file
  local files=()
  case "${SHELL##*/}" in
    zsh) files=("${ZDOTDIR:-$install_home}/.zshrc") ;;
    bash)
      files=("$install_home/.bashrc")
      if [[ -f "$install_home/.bash_profile" ]]; then files+=("$install_home/.bash_profile")
      elif [[ -f "$install_home/.bash_login" ]]; then files+=("$install_home/.bash_login")
      else files+=("$install_home/.profile"); fi ;;
    *) fail '自动配置支持 bash / zsh，请使用页面手动步骤。'; return 1 ;;
  esac
  for file in "${files[@]}"; do
    if ! grep -Fqx -- "$line" "$file" 2>/dev/null; then
      printf '\n%s\n' "$line" >> "$file"
    fi
  done
}
download() {
  [[ -n "$install_tmp" ]] || install_tmp=$(mktemp -d)
  # No pipe-to-shell: failed or empty downloads must not execute.
  curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
    --connect-timeout 20 --max-time 180 "$1" -o "$install_tmp/download"
  [[ -s "$install_tmp/download" ]] || { fail '下载内容为空。'; return 1; }
}
brew_ready() {
  local candidate
  if ! command -v brew >/dev/null 2>&1; then
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      if [[ -x "$candidate" ]]; then export PATH="${candidate%/brew}:$PATH"; break; fi
    done
  fi
  if ! command -v brew >/dev/null 2>&1; then
    [[ $(sw_vers -productVersion | cut -d. -f1) -ge 15 ]] || { fail '新装 Homebrew 需要 macOS 15+；请使用官网安装包。'; return 1; }
    say '首次安装 Homebrew；按官方提示确认并输入电脑密码。'
    download https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
    bash "$install_tmp/download"
    case "$(uname -m)" in arm64) export PATH="/opt/homebrew/bin:$PATH" ;; *) export PATH="/usr/local/bin:$PATH" ;; esac
  fi
  brew --version >/dev/null
  local brew_bin line
  brew_bin=$(command -v brew)
  printf -v line 'eval "$(%q shellenv)"' "$brew_bin"
  profile_line "$line"
}
apt_ready() {
  command -v sudo >/dev/null || { fail '需要 sudo；请联系引路人安装基础工具。'; return 1; }
  sudo apt-get update
}
install_git() {
  if [[ "$install_os" == Darwin ]]; then brew_ready; brew install git
  else apt_ready; sudo apt-get install -y git; fi
}
install_node() {
  if [[ "$install_os" == Darwin ]] && ! xcode-select -p >/dev/null 2>&1; then
    say 'Node 安装需要 Apple Command Line Tools，正在打开系统安装提示。'
    xcode-select --install || { fail '无法启动 Command Line Tools 安装；请运行 xcode-select --install，安装完成后重跑。'; return 1; }
    fail '请在系统窗口完成 Command Line Tools 安装，再运行本脚本继续；当前尚未安装完成。'
    return 1
  fi
  command -v curl >/dev/null || { apt_ready; sudo apt-get install -y curl ca-certificates; }
  export NVM_DIR="${NVM_DIR:-${XDG_CONFIG_HOME:-$install_home}/$([[ -n "${XDG_CONFIG_HOME:-}" ]] && printf nvm || printf .nvm)}"
  if [[ ! -s "$NVM_DIR/nvm.sh" ]]; then
    download https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh
    # We explicitly configure the actual user's shell below.
    PROFILE=/dev/null bash "$install_tmp/download"
  fi
  local nvm_line
  printf -v nvm_line 'export NVM_DIR=%q; [ ! -s "$NVM_DIR/nvm.sh" ] || . "$NVM_DIR/nvm.sh"' "$NVM_DIR"
  profile_line "$nvm_line"
  # nvm supports shells without nounset; restore it after invoking nvm.
  set +u
  . "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm alias default 'lts/*'
  set -u
}
install_gh() {
  if [[ "$install_os" == Darwin ]]; then brew_ready; brew install gh; return; fi
  apt_ready
  sudo apt-get install -y curl ca-certificates
  download https://cli.github.com/packages/githubcli-archive-keyring.gpg
  sudo install -d -m 755 /etc/apt/keyrings /etc/apt/sources.list.d
  # Reuse an existing official source rather than overwriting custom config.
  local source=/etc/apt/sources.list.d/github-cli.list
  local key=/etc/apt/keyrings/githubcli-archive-keyring.gpg
  printf 'deb [arch=%s signed-by=%s] https://cli.github.com/packages stable main\n' "$(dpkg --print-architecture)" "$key" > "$install_tmp/github-cli.list"
  if [[ -e "$source" ]] && ! cmp -s "$source" "$install_tmp/github-cli.list"; then
    fail '现有 GitHub CLI apt 源与官方配置不同，请联系引路人核对。'; return 1
  fi
  sudo install -m 644 "$install_tmp/download" "$key"
  sudo install -m 644 "$install_tmp/github-cli.list" "$source"
  sudo apt-get update
  sudo apt-get install -y gh
}
install_claude() {
  command -v curl >/dev/null || { apt_ready; sudo apt-get install -y curl ca-certificates; }
  download https://claude.ai/install.sh
  bash "$install_tmp/download"
  export PATH="$install_home/.local/bin:$PATH"
  profile_line 'export PATH="$HOME/.local/bin:$PATH"'
}
install_codex() {
  npm install --global --registry=https://registry.npmjs.org @openai/codex
  local prefix line
  prefix=$(npm prefix --global)
  export PATH="$prefix/bin:$PATH"
  printf -v line 'export PATH=%q:"$PATH"' "$prefix/bin"
  profile_line "$line"
}
main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check) install_check=1; shift ;;
      --only) [[ $# -ge 2 ]] || { fail '--only 缺少值。'; return 2; }; install_only=$2; shift 2 ;;
      --help) say '用法：bash install-tools.sh [--only all|base|claude|codex] [--check]'; return ;;
      *) fail "未知参数：$1"; return 2 ;;
    esac
  done
  local tools=() tool missing=0
  case "$install_only" in
    all) tools=(git node gh claude codex) ;;
    base) tools=(git node gh) ;;
    claude) tools=(claude) ;;
    codex) tools=(node codex) ;;
    *) fail '安装范围应为 all / base / claude / codex。'; return 2 ;;
  esac
  trap cleanup EXIT
  trap on_error ERR
  trap 'exit 130' INT
  trap 'exit 143' TERM
  platform
  say "Ali Matrix · 工具准备（范围：${tools[*]}）"
  if (( ! install_check )); then
    [[ $(id -u) -ne 0 ]] || { fail '请在普通用户终端运行，系统安装需要时会单独请求 sudo。'; return 1; }
    case "${SHELL:-}" in */bash|*/zsh) ;; *) fail '自动安装支持 bash / zsh；其他 shell 请用页面手动步骤。'; return 1 ;; esac
    say '仅安装缺失工具；Node 低于 22 时安装 LTS 并设为默认。可能安装 Homebrew/nvm、添加官方 apt 源和 shell PATH。'
    say '工具登录、桌面应用和公司插件请在安装后按页面继续。'
  fi
  for tool in "${tools[@]}"; do
    install_step=$tool
    if tool_ready "$tool"; then
      say "✓ $tool 已就绪，跳过：$("$tool" --version | head -n 1)"
    elif (( install_check )); then
      say "○ $tool 缺失、版本不满足或命令不可用"; missing=1
    else
      if command -v "$tool" >/dev/null 2>&1; then say "→ $tool 已检测到，需更新或修复（Node 至少 22 且 npm/npx 可用）"
      else say "→ $tool 未检测到，首次安装"; fi
      "install_$tool"
      hash -r
      tool_ready "$tool" || { fail "$tool 安装后验证失败。请重开终端检查 PATH，再重跑。"; return 1; }
      say "✓ $tool 验证通过：$("$tool" --version | head -n 1)"
    fi
  done
  (( missing == 0 )) || return 1
  if (( install_check )); then say '检查通过；未安装或修改配置。'
  else
    say '所选工具安装完成。请关闭并重开终端，再运行本脚本 --check 验证。'
    say '下一步：回到指南登录 GitHub、Claude 和 ChatGPT，安装桌面应用，再接入公司 SOP。'
  fi
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
