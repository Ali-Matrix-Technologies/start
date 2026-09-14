#!/usr/bin/env python3
"""Zero-dependency checks for the public GitHub Pages site."""
from html.parser import HTMLParser
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
errors = []


class Page(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.ids, self.links, self.assets, self.steps = [], [], [], []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            self.ids.append(attrs['id'])
        if tag == 'a' and 'href' in attrs:
            self.links.append(attrs['href'])
            if attrs.get('target') == '_blank' and 'noopener' not in attrs.get('rel', ''):
                errors.append('External new-tab link missing noopener: ' + attrs['href'])
        if tag in ('img', 'script') and 'src' in attrs:
            self.assets.append(attrs['src'])
        if tag == 'link' and 'href' in attrs:
            self.assets.append(attrs['href'])
        if tag == 'img' and not attrs.get('alt'):
            errors.append('Image missing alt: ' + attrs.get('src', ''))
        if 'data-step' in attrs:
            self.steps.append((attrs.get('id'), attrs['data-step']))


page = Page()
page.feed((ROOT / 'index.html').read_text())
if len(page.ids) != len(set(page.ids)):
    errors.append('Duplicate HTML IDs')
expected = ['s0', 's1', 's6', 's2', 's3', 's4', 's5', 's9', 's10', 's7', 's8']
if [item[0] for item in page.steps] != expected:
    errors.append('Unexpected onboarding step order')
for href in page.links + page.assets:
    url = urlsplit(href)
    if url.scheme or url.netloc:
        continue
    if url.path and not (ROOT / unquote(url.path)).is_file():
        errors.append('Missing local asset: ' + href)
    if not url.path and url.fragment and unquote(url.fragment) not in page.ids:
        errors.append('Broken section link: ' + href)

# Scan every published text asset, including extracted scripts and SVGs.
# An official npm scope is allowed; personal handles remain forbidden.
private = re.compile(r'\{\{|t\.me/\+|workers\.dev|sk-[A-Za-z0-9]{16,}|ghp_[A-Za-z0-9]{20,}|BEGIN [A-Z ]*PRIVATE KEY')
handle = re.compile(r'@[A-Za-z0-9_]{4,}')
for path in sorted(ROOT.rglob('*')):
    if not path.is_file() or path.suffix not in ('.html', '.md', '.js', '.css', '.svg', '.sh', '.ps1'):
        continue
    if any(part in ('.git', 'node_modules') for part in path.relative_to(ROOT).parts):
        continue
    source = path.read_text()
    if private.search(source):
        errors.append('Possible private information: ' + str(path.relative_to(ROOT)))
    # CSS at-rules are not user handles. All other files allow only this exact npm package.
    if path.suffix != '.css' and handle.search(source.replace('@openai/codex', '')):
        errors.append('Possible personal handle: ' + str(path.relative_to(ROOT)))

if errors:
    print('\n'.join(errors), file=sys.stderr)
    sys.exit(1)
print(f'OK: {len(page.steps)} steps, {len(page.ids)} IDs, {len(page.links)} links; public-content guard passed')
