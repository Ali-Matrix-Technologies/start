"""Installation control-flow tests; commands are mocked, no real installs."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest
import sys
import re
import html

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/install-tools.sh'
MOCKS = r'''
source "$INSTALL_SCRIPT"
install_home="$CASE_ROOT/home"
export NVM_DIR="$CASE_ROOT/nvm"
export SHELL=/bin/bash
export TMPDIR="$CASE_ROOT/tmp"
mkdir -p "$install_home" "$TMPDIR"
id() { echo 1000; }
uname() { if [[ $1 == -s ]]; then echo "${FAKE_OS:-Darwin}"; else echo "${FAKE_ARCH:-arm64}"; fi; }
xcode-select() {
  if [[ "$1" == -p ]]; then [[ "${FAIL_AT:-}" != clt ]]; return; fi
  [[ "$1" == --install ]] || return 94
  echo 'xcode-select --install' >> "$CASE_ROOT/commands"
}
version() {
  [[ -f "$CASE_ROOT/$1" ]] || return 127
  if [[ $1 == node ]]; then cat "$CASE_ROOT/node"; else echo "$1 1.0.0"; fi
}
git() { version git; }
node() { version node; }
gh() { version gh; }
claude() { version claude; }
codex() { version codex; }
npx() { [[ ! -f "$CASE_ROOT/bad-npm" ]]; }
npm() {
  if [[ $1 == --version ]]; then [[ ! -f "$CASE_ROOT/bad-npm" ]]; return; fi
  if [[ $1 == prefix ]]; then echo "$CASE_ROOT/npm"; return; fi
  echo "npm $*" >> "$CASE_ROOT/commands"
  [[ "${FAIL_AT:-}" != npm ]] || return 42
  [[ "$*" == 'install --global --registry=https://registry.npmjs.org @openai/codex' ]] || return 93
  touch "$CASE_ROOT/codex"
}
brew() {
  case "$1" in
    --version) echo 'Homebrew test' ;;
    install)
      echo "brew $*" >> "$CASE_ROOT/commands"
      [[ "${FAIL_AT:-}" != brew ]] || return 42
      [[ "$2" == git || "$2" == gh ]] || return 93
      touch "$CASE_ROOT/$2" ;;
    *) return 94 ;;
  esac
}
sudo() {
  echo "sudo $*" >> "$CASE_ROOT/commands"
  if [[ "$*" == 'apt-get install -y git' ]]; then touch "$CASE_ROOT/git"; fi
  if [[ "$*" == 'apt-get install -y gh' ]]; then touch "$CASE_ROOT/gh"; fi
  return 0
}
curl() {
  echo "curl" >> "$CASE_ROOT/commands"
  local output="${@: -1}" url="${@: -3:1}"
  if [[ "${FAIL_AT:-}" == curl ]]; then
    echo 'touch "$CASE_ROOT/unsafe-executed"' > "$output"
    return 22
  fi
  if [[ "${FAIL_AT:-}" == empty ]]; then : > "$output"; return; fi
  case "$url" in
    https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh)
      cat > "$output" <<'NVM'
mkdir -p "$NVM_DIR"
cat > "$NVM_DIR/nvm.sh" <<'INNER'
nvm() {
  echo "nvm $*" >> "$CASE_ROOT/commands"
  if [[ "$1" == install ]]; then echo v24.0.0 > "$CASE_ROOT/node"; fi
  return 0
}
INNER
NVM
      ;;
    https://claude.ai/install.sh)
      echo 'touch "$CASE_ROOT/claude"' > "$output" ;;
    https://cli.github.com/packages/githubcli-archive-keyring.gpg)
      echo 'mock downloaded key' > "$output" ;;
    *) echo "Unexpected network URL $url" >&2; return 95 ;;
  esac
}
main "$@"
'''


class InstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.env = {**os.environ, 'INSTALL_SCRIPT': str(SCRIPT), 'CASE_ROOT': str(self.root)}

    def installed(self):
        for tool in ['git', 'node', 'gh', 'claude', 'codex']:
            (self.root / tool).write_text('v24.0.0\n')

    def run_script(self, *args, **env):
        return subprocess.run(['/bin/bash', '-c', MOCKS, 'test', *args],
                              env={**self.env, **env}, text=True, capture_output=True, timeout=20)

    def test_missing_install_and_repeat(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        for tool in ['git', 'node', 'gh', 'claude', 'codex']:
            self.assertTrue((self.root / tool).exists(), tool)
        before = (self.root / 'commands').read_text()
        profile = (self.root / 'home/.bashrc').read_text()
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(before, (self.root / 'commands').read_text())
        self.assertEqual(profile, (self.root / 'home/.bashrc').read_text())
        self.assertFalse(list((self.root / 'tmp').iterdir()))

    @unittest.skipUnless(sys.platform.startswith('linux'), 'Linux distro metadata is tested on Ubuntu CI')
    def test_linux_install_uses_scoped_apt_source(self):
        result = self.run_script(FAKE_OS='Linux')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = (self.root / 'commands').read_text()
        self.assertIn('apt-get install -y git', calls)
        self.assertIn('apt-get install -y gh', calls)
        self.assertIn('/etc/apt/keyrings/githubcli-archive-keyring.gpg', calls)
        self.assertNotIn('apt-key', calls)

    def test_check_is_read_only(self):
        self.installed()
        result = self.run_script('--check')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / 'commands').exists())
        self.assertFalse(list((self.root / 'home').iterdir()))
        (self.root / 'node').write_text('v18.0.0\n')
        result = self.run_script('--check')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / 'commands').exists())

    def test_old_node_and_missing_npm(self):
        self.installed()
        (self.root / 'node').write_text('v18.0.0\n')
        result = self.run_script('--only', 'base')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('需更新', result.stdout)
        self.assertNotIn('brew', (self.root / 'commands').read_text())
        (self.root / 'bad-npm').touch()
        result = self.run_script('--only', 'base')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('验证失败', result.stderr)

    def test_scope_and_dependency(self):
        result = self.run_script('--only', 'codex')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / 'node').exists())
        self.assertTrue((self.root / 'codex').exists())
        self.assertFalse((self.root / 'git').exists())
        self.assertFalse((self.root / 'claude').exists())

    def test_fresh_mac_requests_clt_before_nvm_and_can_resume(self):
        result = self.run_script('--only', 'codex', FAIL_AT='clt')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('系统窗口', result.stderr)
        self.assertEqual((self.root / 'commands').read_text(), 'xcode-select --install\n')
        self.assertFalse((self.root / 'node').exists())
        result = self.run_script('--only', 'codex')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / 'codex').exists())

    def test_copied_unix_wrappers_reject_failed_or_empty_download(self):
        page = (SCRIPT.parents[1] / 'index.html').read_text()
        blocks = [html.unescape(block) for block in re.findall(r'<code>(.*?)</code>', page, re.S)
                  if 'install-tools.sh' in block]
        self.assertEqual(len(blocks), 6)
        temp_dir = self.root / 'wrappers'
        temp_dir.mkdir()
        mock = r'''
curl() {
  local output="${@: -1}"
  if [[ "$WRAPPER_CASE" == empty ]]; then : > "$output"; return; fi
  printf 'touch "%s/executed"\nexit %s\n' "$CASE_ROOT" "$PAYLOAD_EXIT" > "$output"
  [[ "$WRAPPER_CASE" != download-error ]]
}
'''
        for block in blocks:
            for case, payload_exit in [('empty', '0'), ('download-error', '0'),
                                       ('success', '0'), ('installer-error', '23')]:
                marker = self.root / 'executed'
                marker.unlink(missing_ok=True)
                result = subprocess.run(['/bin/bash', '-c', mock + block], text=True,
                    capture_output=True, timeout=10, env={**self.env, 'TMPDIR': str(temp_dir),
                    'WRAPPER_CASE': case, 'PAYLOAD_EXIT': payload_exit})
                self.assertEqual(result.returncode == 0, case == 'success', result.stderr)
                self.assertEqual(marker.exists(), case in ['success', 'installer-error'])
                self.assertFalse(list(temp_dir.iterdir()))

    def test_download_failure_and_empty_never_execute(self):
        for failure in ['curl', 'empty']:
            result = self.run_script('--only', 'claude', FAIL_AT=failure)
            self.assertNotEqual(result.returncode, 0)
            self.assertNotIn('所选工具安装完成', result.stdout)
            self.assertFalse((self.root / 'unsafe-executed').exists())
            self.assertFalse(list((self.root / 'tmp').iterdir()))

    def test_package_failure_stops_next_tool(self):
        result = self.run_script(FAIL_AT='brew')
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.root / 'node').exists())
        self.assertNotIn('所选工具安装完成', result.stdout)

    def test_npm_failure_is_not_success(self):
        result = self.run_script('--only', 'codex', FAIL_AT='npm')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('codex', result.stderr)
        self.assertFalse((self.root / 'codex').exists())

    def test_invalid_args_os_arch_rejected_before_writes(self):
        for args, env in [(['--only'], {}), (['--only', 'wrong'], {}), (['--oops'], {}),
                          ([], {'FAKE_OS': 'FreeBSD'}), ([], {'FAKE_ARCH': 'i686'})]:
            result = self.run_script(*args, **env)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((self.root / 'commands').exists())


if __name__ == '__main__':
    unittest.main()
