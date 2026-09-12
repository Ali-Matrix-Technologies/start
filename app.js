(() => {
  'use strict';
  // Preserve the original step IDs and storage key when reordering the guide.
  const KEY = 'ali-start-v1';
  const steps = [...document.querySelectorAll('.step[data-step]')];
  const ids = steps.map(step => step.id);
  const views = [...document.querySelectorAll('main > .step')];
  const osNames = { mac: 'macOS', win: 'Windows', linux: 'Linux' };
  const mobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent) ||
    (/Macintosh/i.test(navigator.userAgent) && navigator.maxTouchPoints > 1);
  const dependencies = {
    s7: ['s1', 's6', 's2', 's3', 's4', 's5', 's9', 's10'],
    s8: ['s1', 's6', 's2', 's3', 's4', 's5', 's9', 's10', 's7']
  };
  let storageAvailable = true;
  let raw = {};
  try { raw = JSON.parse(localStorage.getItem(KEY) || '{}'); } catch { storageAvailable = false; }
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) raw = {};
  const state = { version: 3, done: {}, os: null, osConfirmed: raw.osConfirmed === true, current: ids.includes(raw.current) ? raw.current : null, waiting: raw.waiting === true };
  steps.forEach(step => { state.done[step.dataset.step] = raw.done?.[step.dataset.step] === true; });
  // The updated SOP step verifies both AI tools; a Claude-only completion cannot prove this.
  if (raw.version !== 3) { state.done['7'] = false; state.done['8'] = false; }
  if (Object.hasOwn(osNames, raw.os) && (!mobile || (raw.version >= 2 && state.osConfirmed))) state.os = raw.os;
  if (!state.os && !mobile) {
    if (/Windows/i.test(navigator.userAgent)) state.os = 'win';
    else if (/Mac/i.test(navigator.userAgent)) state.os = 'mac';
    else if (/Linux/i.test(navigator.userAgent)) state.os = 'linux';
  }
  if (state.done['6']) state.waiting = false;
  const done = id => state.done[id.slice(1)] === true;
  const missing = id => (dependencies[id] || []).filter(required => !done(required));
  const title = id => document.getElementById(id).dataset.title;
  const needsOS = id => ['s2', 's5', 's10'].includes(id) && !state.os;
  const allDone = () => ids.every(done);
  function nextTask() {
    const available = ids.find(id => !done(id) && !(id === 's6' && state.waiting));
    // Finish independent setup while approval is pending; return before installing SOP.
    if (state.waiting && (!available || ['s7', 's8'].includes(available))) return 's6';
    return available || 'complete';
  }
  function save() {
    try { localStorage.setItem(KEY, JSON.stringify(state)); storageAvailable = true; }
    catch { storageAvailable = false; }
    document.getElementById('save-note').textContent = storageAvailable
      ? '进度保存在当前浏览器，随时回来继续。'
      : '浏览器无法保存进度，关闭页面后可能丢失。';
  }
  let toastTimer;
  function notify(message) {
    const toast = document.getElementById('toast');
    clearTimeout(toastTimer);
    toast.textContent = message;
    toast.hidden = false;
    toastTimer = setTimeout(() => { toast.hidden = true; }, 3000);
  }
  function showPrerequisites(id, targetId) {
    const target = document.getElementById(targetId);
    const required = missing(id);
    target.replaceChildren();
    target.hidden = !required.length;
    if (!required.length) return;
    const heading = document.createElement('b');
    heading.textContent = '先确认前面的准备已完成';
    const description = document.createElement('p');
    description.textContent = '本页还有以下步骤未确认。如果已经做过，回到对应步骤勾选完成标准即可。';
    const list = document.createElement('ul');
    required.forEach(requiredId => {
      const item = document.createElement('li');
      const link = document.createElement('a');
      link.href = '#' + requiredId;
      link.textContent = title(requiredId) + (requiredId === 's6' && state.waiting ? '（等待审批 / 接受邀请）' : '');
      item.append(link); list.append(item);
    });
    target.append(heading, description, list);
  }
  function render() {
    const count = ids.filter(done).length;
    document.getElementById('ptext').textContent = `${count} / ${ids.length}`;
    document.getElementById('progress').value = count;
    document.getElementById('progress').textContent = `${count} / ${ids.length}`;
    document.getElementById('progress').setAttribute('aria-valuetext', `已完成 ${count} 项，共 ${ids.length} 项`);
    const next = nextTask();
    const resume = document.getElementById('resume');
    resume.href = '#' + next;
    resume.textContent = allDone() ? '查看完成结果 →' : next === 's6' && state.waiting ? '回去查看邀请 →' : count ? '继续未完成步骤 →' : '开始第一步 →';
    document.querySelectorAll('[data-nav]').forEach(link => {
      const id = link.dataset.nav;
      link.classList.toggle('is-done', done(id));
      link.querySelector('.nav-number').textContent = done(id) ? '✓' : ids.indexOf(id) + 1;
      link.querySelector('.nav-status').textContent = id === 's6' && state.waiting ? '等待中' : '';
      link.setAttribute('aria-label', `${ids.indexOf(id) + 1}. ${title(id)}，${done(id) ? '已完成' : id === 's6' && state.waiting ? '等待中' : '未完成'}`);
    });
    steps.forEach(step => {
      const box = step.querySelector('input[type="checkbox"]');
      const blocked = missing(step.id).length > 0 || needsOS(step.id);
      box.checked = done(step.id);
      box.disabled = blocked && !box.checked;
      const nextButton = step.querySelector('.next-button');
      nextButton.disabled = !done(step.id) || blocked;
      nextButton.textContent = step.id === 's8' ? '完成入门 →' : '下一步 →';
      step.querySelector('.action-hint').textContent = blocked
        ? needsOS(step.id) ? '先在上方选择安装用的电脑系统。' : '先确认上面列出的准备步骤。'
        : done(step.id) ? '已记录。也可以从步骤目录回看任何一步。' : '达到完成标准后，勾选上方确认即可继续。';
    });
    showPrerequisites('s7', 'prerequisites');
    showPrerequisites('s8', 'first-message-prerequisites');
    document.getElementById('install-content').hidden = missing('s7').length > 0;
    document.getElementById('wait-approval').closest('.waiting').hidden = done('s6');
    document.querySelectorAll('.return-step').forEach(link => { link.href = '#' + (state.current || nextTask()); });
    document.getElementById('help-template').textContent = `我在完成 Ali Matrix 新人指南。\n当前步骤：${title(state.current || 's0')}\n电脑系统：${osNames[state.os] || '[填写安装用的电脑系统]'}\n我做了什么：[填写操作或命令]\n实际结果：[粘贴完整报错，可附截图]\n我已经试过：[填写尝试过的办法]`;
  }
  function route(id, { focus = true } = {}) {
    if (!views.some(view => view.id === id)) id = state.current || nextTask();
    if (id === 'complete' && !allDone()) id = nextTask();
    if (location.hash !== '#' + id) history.replaceState(null, '', '#' + id);
    views.forEach(view => { view.hidden = view.id !== id; });
    if (ids.includes(id)) state.current = id;
    document.querySelectorAll('[data-nav]').forEach(link => {
      if (link.dataset.nav === id) link.setAttribute('aria-current', 'step');
      else link.removeAttribute('aria-current');
    });
    document.getElementById('mobile-position').textContent = ids.includes(id) ? `第 ${ids.indexOf(id) + 1} / ${ids.length} 步` : '参考与帮助';
    document.getElementById('os').hidden = !ids.includes(id);
    document.title = `${ids.includes(id) ? title(id) : document.getElementById(id).querySelector('h2').textContent} · Ali Matrix 入门指南`;
    save(); render();
    if (focus) {
      if (matchMedia('(max-width: 820px)').matches) document.querySelector('.journey').open = false;
      document.getElementById(id).querySelector('h2').focus({ preventScroll: true });
      document.getElementById('workspace').scrollIntoView({ block: 'start' });
    }
  }
  function navigate(id) {
    if (location.hash === '#' + id) route(id);
    else location.hash = id;
  }
  steps.forEach((step, index) => {
    const footer = document.createElement('div');
    footer.className = 'step-actions';
    const label = document.createElement('label');
    label.className = 'done-label';
    const box = document.createElement('input');
    box.type = 'checkbox';
    label.append(box, document.createTextNode(step.dataset.confirm));
    const row = document.createElement('div'); row.className = 'action-row';
    if (index > 0) {
      const previous = document.createElement('a');
      previous.className = 'text-button'; previous.href = '#' + ids[index - 1]; previous.textContent = '← 上一步'; row.append(previous);
    }
    const help = document.createElement('a'); help.href = '#help'; help.className = 'text-button'; help.textContent = '这一步卡住了'; row.append(help);
    const next = document.createElement('button'); next.type = 'button'; next.className = 'button primary next-button'; row.append(next);
    const hint = document.createElement('p'); hint.className = 'action-hint';
    hint.id = `${step.id}-action-hint`; next.setAttribute('aria-describedby', hint.id);
    box.setAttribute('aria-describedby', hint.id);
    footer.append(label, row, hint); step.append(footer);
    box.addEventListener('change', () => {
      state.done[step.dataset.step] = box.checked;
      if (step.id === 's6' && box.checked) state.waiting = false;
      save(); render();
      document.getElementById('announcement').textContent = `${title(step.id)}${box.checked ? '已完成' : '已标记为未完成'}，共完成 ${ids.filter(done).length} 步。`;
    });
    next.addEventListener('click', () => {
      if (!done(step.id) || missing(step.id).length || needsOS(step.id)) return;
      // Continue forward when reviewing completed steps; return to any remaining gaps at the end.
      const following = ids.slice(index + 1).find(id => !done(id) && !(id === 's6' && state.waiting));
      navigate(state.waiting && (!following || ['s7', 's8'].includes(following)) ? 's6' : following || nextTask());
    });
  });
  function setOS(os, confirmed = false) {
    state.os = os;
    if (confirmed) state.osConfirmed = true;
    document.querySelectorAll('#os button').forEach(button => { button.setAttribute('aria-pressed', String(button.dataset.os === os)); });
    document.querySelectorAll('.panel').forEach(panel => { panel.classList.toggle('on', panel.dataset.os === os); });
    document.querySelectorAll('.os-required').forEach(panel => { panel.hidden = Boolean(os); });
    document.getElementById('os-hint').textContent = !os ? '在手机上看指南？请选择安装用的电脑系统。' : state.osConfirmed ? `当前显示 ${osNames[os]} 的安装步骤，可随时切换。` : `根据当前电脑预选 ${osNames[os]}，也可以手动切换。`;
    document.querySelectorAll('.command-label[data-terminal]').forEach(label => { label.textContent = os === 'win' ? 'PowerShell · 每次执行一条' : '终端 · 每次执行一条'; });
    save(); render();
  }
  document.querySelectorAll('#os button').forEach(button => button.addEventListener('click', () => setOS(button.dataset.os, true)));
  document.getElementById('wait-approval').addEventListener('click', () => {
    state.waiting = true; state.done['6'] = false; save(); render(); navigate('s2');
    notify('已记为等待中。先装工具，接入公司流程前再回来。');
  });
  document.querySelectorAll('pre').forEach(pre => {
    const wrapper = document.createElement('div'); wrapper.className = 'command';
    const bar = document.createElement('div'); bar.className = 'command-bar';
    const label = document.createElement('span'); label.className = 'command-label';
    label.textContent = pre.dataset.context || '终端 · 每次执行一条';
    if (!pre.dataset.context) label.dataset.terminal = '';
    const button = document.createElement('button'); button.type = 'button'; button.className = 'copy'; button.textContent = '复制';
    button.setAttribute('aria-label', pre.dataset.context?.startsWith('求助') ? '复制求助模板' : `复制 ${pre.querySelector('code').textContent}`);
    bar.append(label, button); pre.before(wrapper); wrapper.append(bar, pre);
    let resetTimer;
    button.addEventListener('click', async () => {
      const text = pre.querySelector('code').textContent;
      let copied = false;
      if (navigator.clipboard && window.isSecureContext) {
        try { await navigator.clipboard.writeText(text); copied = true; } catch { /* Try the selection-based fallback. */ }
      }
      if (!copied) {
        const area = document.createElement('textarea'); area.value = text;
        area.style.cssText = 'position:fixed;top:0;left:0;opacity:0;font-size:16px';
        document.body.append(area); area.focus({ preventScroll: true }); area.select();
        try { copied = document.execCommand('copy'); } catch { /* Show manual selection below. */ }
        area.remove(); button.focus({ preventScroll: true });
      }
      clearTimeout(resetTimer);
      button.textContent = copied ? '✓ 已复制' : '手动复制';
      button.classList.toggle('ok', copied); button.classList.toggle('manual', !copied);
      if (!copied) {
        const range = document.createRange(); range.selectNodeContents(pre.querySelector('code'));
        const selection = window.getSelection(); selection.removeAllRanges(); selection.addRange(range);
        notify('自动复制不可用，已选中文字，请手动复制。');
      } else document.getElementById('announcement').textContent = '已复制到剪贴板。';
      resetTimer = setTimeout(() => { button.textContent = '复制'; button.classList.remove('ok', 'manual'); }, 2000);
    });
  });
  const compact = matchMedia('(max-width: 820px)');
  const updateJourney = () => { document.querySelector('.journey').open = !compact.matches; };
  updateJourney(); compact.addEventListener('change', updateJourney);
  window.addEventListener('hashchange', () => route(location.hash.slice(1)));
  document.querySelectorAll('a[href^="#"]').forEach(link => link.addEventListener('click', event => {
    if (link.hash === location.hash && views.some(view => '#' + view.id === link.hash)) { event.preventDefault(); route(link.hash.slice(1)); }
  }));
  // Enable the focused view only after controls are built; the full guide works without JS.
  document.documentElement.classList.add('enhanced');
  setOS(state.os);
  route(location.hash.slice(1) || (allDone() ? 'complete' : state.current || nextTask()), { focus: false });
  if (raw.version !== 3 && (raw.done?.['7'] === true || raw.done?.['8'] === true)) {
    notify('已保留原有准备进度。新增 Codex 后，请重新确认公司插件安装和首次对话。');
  }
})();
