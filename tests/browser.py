"""Browser regression checks. Run: uv run --with playwright python tests/browser.py"""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
from tempfile import gettempdir
from threading import Thread
from playwright.sync_api import sync_playwright, expect

ROOT = Path(__file__).resolve().parents[1]
KEY = 'ali-start-v1'
ORDER = ['s0', 's1', 's6', 's2', 's3', 's4', 's5', 's9', 's10', 's7', 's8']
REFS = ['tools', 'telegram', 'teleport', 'commands', 'glossary', 'help', 'project-work']
ARTIFACTS = Path(os.environ.get('SCREENSHOT_DIR', str(Path(gettempdir()) / 'ali-start-qa')))
ARTIFACTS.mkdir(parents=True, exist_ok=True)


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass


server = ThreadingHTTPServer(('127.0.0.1', 0), partial(QuietHandler, directory=str(ROOT)))
Thread(target=server.serve_forever, daemon=True).start()
URL = f'http://127.0.0.1:{server.server_port}'
errors = []


def open_page(context, fragment=''):
    page = context.new_page()
    page.on('pageerror', lambda error: errors.append(str(error)))
    page.goto(URL + '/' + fragment)
    return page


def go(page, step):
    page.evaluate('(id) => { location.hash = id; }', step)
    expect(page.locator(f'main > #{step}')).to_be_visible()
    expect(page.locator('main > .step:visible')).to_have_count(1)


def mark(page, step):
    go(page, step)
    page.locator(f'#{step} input[type=checkbox]').check()


try:
    with sync_playwright() as pw:
        channel = os.environ.get('BROWSER_CHANNEL', 'chrome')
        browser = pw.chromium.launch(**({} if channel == 'chromium' else {'channel': channel}))
        context = browser.new_context(viewport={'width': 1440, 'height': 1000}, permissions=['clipboard-read', 'clipboard-write'])
        page = open_page(context)
        expect(page.locator('#s0')).to_be_visible()
        expect(page.locator('#ptext')).to_have_text('0 / 11')
        expect(page.locator('#s0 .next-button')).to_be_disabled()
        page.screenshot(path=str(ARTIFACTS / 'desktop.png'), full_page=True)

        # A newcomer submits early, prepares tools while waiting, then returns to the invite.
        mark(page, 's0')
        page.locator('#s0 .next-button').click()
        expect(page.locator('#s1')).to_be_visible()
        page.go_back()
        expect(page.locator('#s0')).to_be_visible()
        mark(page, 's1')
        go(page, 's6')
        page.locator('#wait-approval').click()
        expect(page.locator('#s2')).to_be_visible()
        expect(page.locator('[data-nav=s6] .nav-status')).to_have_text('等待中')
        page.locator('#os [data-os=win]').click()
        expect(page.locator('#s2 .panel.on')).to_have_attribute('data-os', 'win')
        go(page, 's7')
        expect(page.locator('#install-content')).to_be_hidden()
        expect(page.locator('#prerequisites')).to_contain_text('等待审批')
        expect(page.locator('#s7 input')).to_be_disabled()
        for step in ['s2', 's3', 's4', 's5', 's9', 's10']:
            mark(page, step)
        page.locator('#s10 .next-button').click()
        expect(page.locator('#s6')).to_be_visible()
        page.reload()
        expect(page.locator('[data-nav=s6] .nav-status')).to_have_text('等待中')
        expect(page.locator('#os [data-os=win]')).to_have_attribute('aria-pressed', 'true')
        mark(page, 's6')
        page.locator('#s6 .next-button').click()
        expect(page.locator('#s7')).to_be_visible()
        expect(page.locator('#install-content')).to_be_visible()
        expect(page.locator('#install-content code')).to_have_text('npx github:Ali-Matrix-Technologies/ali-sop')
        page.locator('#install-content .copy').click()
        expect(page.locator('#install-content .copy')).to_have_text('✓ 已复制')
        assert page.evaluate('navigator.clipboard.readText()') == 'npx github:Ali-Matrix-Technologies/ali-sop'
        mark(page, 's7')
        mark(page, 's8')
        page.locator('#s8 .next-button').click()
        expect(page.locator('#complete')).to_be_visible()
        expect(page.locator('#ptext')).to_have_text('11 / 11')
        page.reload()
        expect(page.locator('#complete')).to_be_visible()
        # Reopening a prerequisite prevents false completion, even with old downstream checks.
        go(page, 's6')
        page.locator('#s6 input').uncheck()
        go(page, 's7')
        expect(page.locator('#install-content')).to_be_hidden()
        expect(page.locator('#s7 .next-button')).to_be_disabled()
        go(page, 'help')
        expect(page.locator('#help-template')).to_contain_text('接入公司流程')
        expect(page.locator('#help-template')).to_contain_text('Windows')
        page.locator('#help .return-step').click()
        expect(page.locator('#s7')).to_be_visible()

        # Storage migration keeps step identity after the order changes; new checks are not fabricated.
        migration = browser.new_context()
        legacy = {'os': 'win', 'done': {str(i): True for i in range(9)}}
        migration.add_init_script(f'localStorage.setItem({json.dumps(KEY)}, {json.dumps(json.dumps(legacy))});')
        old_page = open_page(migration)
        expect(old_page.locator('#ptext')).to_have_text('7 / 11')
        expect(old_page.locator('#s9')).to_be_visible()
        expect(old_page.locator('[data-nav=s6]')).to_have_class('is-done')
        go(old_page, 's7')
        expect(old_page.locator('#install-content')).to_be_hidden()

        # Corrupt or unavailable storage must not break the page.
        for value in ['null', '[]', '"bad"', '{broken', '{"done":{"0":"false"},"os":"other"}']:
            isolated = browser.new_context()
            isolated.add_init_script(f'localStorage.setItem({json.dumps(KEY)}, {json.dumps(value)});')
            bad = open_page(isolated)
            expect(bad.locator('#s0')).to_be_visible()
            expect(bad.locator('#ptext')).to_have_text('0 / 11')
            isolated.close()
        blocked = browser.new_context()
        blocked.add_init_script("Object.defineProperty(window, 'localStorage', {get() { throw new Error('Storage blocked'); }});")
        no_storage = open_page(blocked)
        expect(no_storage.locator('#save-note')).to_contain_text('无法保存')
        mark(no_storage, 's0')
        expect(no_storage.locator('#ptext')).to_have_text('1 / 11')

        # A rejected clipboard and a false execCommand result must never report success.
        no_storage.evaluate("Object.defineProperty(navigator, 'clipboard', {value: {writeText: () => Promise.reject(new Error('Denied'))}}); document.execCommand = () => false;")
        go(no_storage, 's3')
        no_storage.locator('#s3 .copy').first.click()
        expect(no_storage.locator('#s3 .copy').first).to_have_text('手动复制')
        assert no_storage.evaluate('getSelection().toString()') == 'gh auth login -h github.com -p https -w'

        # Phones must choose the computer OS; Android is not Linux and iOS is not macOS.
        for device in ['iPhone 13', 'Pixel 7']:
            phone = browser.new_context(**pw.devices[device])
            phone_page = open_page(phone, '#s2')
            expect(phone_page.locator('#os button[aria-pressed=true]')).to_have_count(0)
            expect(phone_page.locator('#s2 .os-required')).to_be_visible()
            expect(phone_page.locator('#s2 .panel:visible')).to_have_count(0)
            phone_page.locator('#os [data-os=win]').click()
            phone_page.reload()
            expect(phone_page.locator('#s2 .panel.on')).to_have_attribute('data-os', 'win')
            phone_page.locator('#os [data-os=mac]').click()
            go(phone_page, 's0')
            phone_page.screenshot(path=str(ARTIFACTS / (device.replace(' ', '-') + '.png')), full_page=True)
            for width in [320, 390, 768]:
                phone_page.set_viewport_size({'width': width, 'height': 844})
                for view in ORDER + REFS:
                    go(phone_page, view)
                    assert phone_page.evaluate('document.documentElement.scrollWidth <= innerWidth'), (device, width, view, 'horizontal overflow')
                    if view == 'project-work':
                        assert phone_page.locator('#project-work .next-links').evaluate('(n)=>[...n.children].every(c=>c.getBoundingClientRect().right<=n.getBoundingClientRect().right+1)'), (device,width,'clipped project card')
            phone_page.set_viewport_size({'width':390,'height':844})
            go(phone_page, 'project-work')
            expect(phone_page.locator('#project-work')).to_contain_text('独立 worktree')
            expect(phone_page.locator('#project-work')).to_contain_text('远程分支和本地分支')
            phone_page.screenshot(path=str(ARTIFACTS / (device.replace(' ', '-') + '-project.png')), full_page=True)
            phone.close()

        # Dark mode and reduced motion, plus current-step focus and deep links.
        dark = browser.new_context(viewport={'width': 1280, 'height': 960}, color_scheme='dark', reduced_motion='reduce')
        dark_page = open_page(dark, '#tools')
        expect(dark_page.locator('#tools')).to_be_visible()
        dark_page.screenshot(path=str(ARTIFACTS / 'dark-tools.png'), full_page=True)
        go(dark_page, 's5')
        expect(dark_page.locator('#s5 h2')).to_be_focused()
        assert dark_page.locator('#os button').first.evaluate('(el) => getComputedStyle(el).transitionDuration') == '0s'

        # Without JavaScript the original HTML remains a complete readable guide.
        static = browser.new_context(java_script_enabled=False)
        static_page = open_page(static)
        expect(static_page.locator('.step[data-step]:visible')).to_have_count(11)
        expect(static_page.locator('#s2 .panel:visible')).to_have_count(3)
        expect(static_page.locator('#teleport')).to_contain_text('尚未上线')

        assert not errors, errors
        # Script commands are OS-specific, copied as a complete block, and remain
        # a manual progress step. Both public assets are served as real files.
        setup = browser.new_context(viewport={'width': 390, 'height': 844}, permissions=['clipboard-read', 'clipboard-write'])
        setup_page = open_page(setup, '#s2')
        for os_name, suffix in [('mac', 'sh'), ('win', 'ps1'), ('linux', 'sh')]:
            setup_page.locator(f'#os [data-os={os_name}]').click()
            command = setup_page.locator('#s2 .panel.on .installer-command').first
            expected = command.locator('pre code').inner_text()
            assert f'install-tools.{suffix}' in expected
            assert ('-Only all' if os_name == 'win' else '--only all') in expected
            command.locator('.copy').click()
            assert setup_page.evaluate('navigator.clipboard.readText()') == expected
            expect(setup_page.locator('#s2 input')).not_to_be_checked()
            expect(setup_page.locator('#s2 .manual-install:visible')).to_have_count(1)
            assert setup.request.get(URL + f'/scripts/install-tools.{suffix}').status == 200
            setup_page.screenshot(path=str(ARTIFACTS / f'installer-{os_name}-mobile.png'), full_page=True)
        setup_page.set_viewport_size({'width': 1440, 'height': 1000})
        setup_page.locator('#os [data-os=mac]').click()
        setup_page.screenshot(path=str(ARTIFACTS / 'installer-desktop.png'), full_page=True)
        setup.close()
        browser.close()
        print('PASS: onboarding, approval, prerequisites, history, persistence, migration, clipboard, mobile, dark, reduced motion, no-JS')
        print(f'Screenshots: {ARTIFACTS}')
finally:
    server.shutdown()
    server.server_close()
