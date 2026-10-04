/* Bootstrap, hash router and all event wiring. */

import {
  content, state, loadContent, loadLocal, applyTheme, setPref, subscribe, persist, flushRemote,
  toggleDone, toggleFav, setNotes, addTag, removeTag, renameTag,
  addResource, updateResource, removeResource,
  addGlobalResource, updateGlobalResource, removeGlobalResource, globalResources,
  resourcesOf, resetProgress, resetEverything, exportState, hydrate,
  moduleProgress, sectionProgress, isDone, notesOf,
  addCustomModule, addCustomSection, addCustomItem, updateCustom, removeCustom,
} from './store.js?v=7';
import * as G from './gist.js?v=7';
import {
  filters, filtersActive, itemCard, fillItemBody, refreshItemBodyBlocks,
  viewDashboard, viewModule, viewBrowse, viewResources, viewSettings,
  renderSidebarProgress, renderSidebarModules, renderFilterBar, THEMES,
} from './views.js?v=7';
import { invalidateDiagrams, renderMarkdown, enhance } from './md.js?v=7';
import { $, $$, esc, pct, debounce, toast, modal, confirmModal, barHtml, safeUrl } from './util.js?v=7';

/* ------------------------------------------------------------- route */
let route = { name: 'dashboard', moduleId: null, sectionId: null, itemId: null };

function parseHash() {
  const raw = location.hash.replace(/^#\/?/, '');
  const [pathPart, queryPart] = raw.split('?');
  const seg = pathPart.split('/').filter(Boolean).map(decodeURIComponent);
  const query = new URLSearchParams(queryPart || '');

  if (seg[0] === 'm' && seg[1]) {
    const mod = content.moduleById.get(seg[1]);
    // `#/m/<mod>/<section>/<item>`, with `#/m/<mod>/<item>` still understood.
    const isSection = mod && seg[2] && mod.sections.some((s) => s.id === seg[2]);
    return {
      name: 'module',
      moduleId: seg[1],
      sectionId: isSection ? seg[2] : null,
      itemId: isSection ? (seg[3] || null) : (seg[2] || null),
      query,
    };
  }
  if (seg[0] === 'browse') return { name: 'browse', query };
  if (seg[0] === 'resources') return { name: 'resources', query };
  if (seg[0] === 'settings') return { name: 'settings', query };
  return { name: 'dashboard', query };
}

/** An item deep link without its section still has to land in that section. */
function resolveRoute(r) {
  if (r.name !== 'module' || !r.itemId || r.sectionId) return r;
  const sec = content.itemSection.get(r.itemId);
  return sec ? { ...r, sectionId: sec.id } : r;
}

function render() {
  route = resolveRoute(parseHash());
  const view = $('#view');

  if (route.name === 'browse') {
    if (route.query.get('fav') === '1') filters.fav = true;
    if (route.query.get('notes') === '1') filters.notes = true;
    if (route.query.get('tag')) filters.tags.add(route.query.get('tag'));
    if (route.query.has('fav') || route.query.has('notes') || route.query.has('tag')) {
      history.replaceState(null, '', '#/browse');
      route.query = new URLSearchParams();
    }
  }

  let html = '';
  if (route.name === 'module') {
    const mod = content.moduleById.get(route.moduleId);
    html = mod
      ? viewModule(mod, route.sectionId, route.itemId)
      : '<div class="empty-state"><div class="big">🤷</div><p>Unknown module.</p></div>';
  } else if (route.name === 'browse') html = viewBrowse();
  else if (route.name === 'resources') html = viewResources();
  else if (route.name === 'settings') html = viewSettings();
  else html = viewDashboard();

  view.innerHTML = html;
  window.scrollTo({ top: 0 });

  $$('.nav-link').forEach((a) => a.classList.toggle('active', a.dataset.nav === route.name));
  renderSidebarProgress();
  renderSidebarModules(route.name === 'module' ? route.moduleId : null);
  renderFilterBar();
  syncFilterChrome();

  if (route.name === 'module' && route.itemId) {
    const card = $(`[data-id="${CSS.escape(route.itemId)}"]`, view);
    if (card) {
      openCard(card, true);
      setTimeout(() => card.scrollIntoView({ block: 'center', behavior: 'smooth' }), 60);
    }
  }
}

/* ----------------------------------------------------- progress sync */
function updateProgressUI() {
  renderSidebarProgress();
  renderSidebarModules(route.name === 'module' ? route.moduleId : null);

  if (route.name !== 'module') return;
  const mod = content.moduleById.get(route.moduleId);
  if (!mod) return;

  const mp = moduleProgress(mod);
  const head = $('.page-head .bar-row');
  if (head) {
    head.innerHTML = `${barHtml(pct(mp.done, mp.total), pct(mp.done, mp.total) === 100 ? 'ok' : '')}
      <span class="pct">${mp.done}/${mp.total} · ${pct(mp.done, mp.total)}%</span>`;
  }

  const open = $('.sec-block.open-section');
  if (open) {
    const sec = mod.sections.find((s) => s.id === open.dataset.section);
    const sp = sec ? sectionProgress(sec) : null;
    const mini = $('.mini', open);
    if (mini && sp && sp.total) {
      mini.innerHTML = barHtml(pct(sp.done, sp.total), sp.done === sp.total ? 'ok' : 'thin');
      mini.nextElementSibling.textContent = `${sp.done}/${sp.total}`;
    }
  }

  // the sticky rail carries its own per-section counters
  $$('.sec-rail .rail-tab[href]').forEach((tab) => {
    const id = tab.getAttribute('href').split('/').pop();
    const sec = mod.sections.find((s) => s.id === id);
    if (!sec) return;
    const sp = sectionProgress(sec);
    const meta = $('.rt-meta', tab);
    const bar = $('.rt-bar i', tab);
    if (meta && sp.total) meta.textContent = `${sp.done}/${sp.total}`;
    if (bar) bar.style.width = `${pct(sp.done, sp.total)}%`;
  });
}

function patchCard(id) {
  const card = $(`.item[data-id="${CSS.escape(id)}"]`);
  if (!card) return;
  const item = content.itemById.get(id);
  if (!item) return;
  const wasOpen = card.classList.contains('open');
  const bodyEl = card.querySelector('.item-body');
  const keptBody = bodyEl && bodyEl.dataset.filled === '1' ? bodyEl : null;

  const tmp = document.createElement('div');
  tmp.innerHTML = itemCard(item, { showModule: card.dataset.showmod === '1', open: wasOpen });
  card.querySelector('.item-head').replaceWith(tmp.firstElementChild.querySelector('.item-head'));
  card.classList.toggle('done', isDone(id));
  if (keptBody) { keptBody.hidden = !wasOpen; refreshItemBodyBlocks(card); }
}

/* --------------------------------------------------------- card open */
async function openCard(card, force = null) {
  const open = force === null ? !card.classList.contains('open') : force;
  card.classList.toggle('open', open);
  const body = card.querySelector('.item-body');
  body.hidden = !open;
  if (open) await fillItemBody(card);
}

/* ----------------------------------------------------------- modals */
function fieldHtml(f) {
  if (f.type === 'select') {
    return `<select id="f-${f.name}" name="${f.name}">${f.options.map((o) =>
      `<option value="${esc(o[0])}" ${o[0] === f.value ? 'selected' : ''}>${esc(o[1])}</option>`).join('')}</select>`;
  }
  if (f.type === 'textarea') {
    return `<textarea id="f-${f.name}" name="${f.name}" rows="${f.rows || 8}" placeholder="${esc(f.placeholder || '')}">${esc(f.value || '')}</textarea>`;
  }
  return `<input id="f-${f.name}" name="${f.name}" type="${f.type || 'text'}" value="${esc(f.value || '')}"
    placeholder="${esc(f.placeholder || '')}" ${f.required ? 'required' : ''} />`;
}

function promptModal({ title, hint = '', fields, submitLabel = 'Save', onSubmit }) {
  modal({
    render: () => `
      <h3>${esc(title)}</h3>
      ${hint ? `<p class="hint">${hint}</p>` : ''}
      <form>
        ${fields.map((f) => `<div class="field">
          <label for="f-${f.name}">${esc(f.label)}</label>
          ${fieldHtml(f)}
        </div>`).join('')}
        <div class="modal-actions">
          <button type="button" class="btn" data-x="cancel">Cancel</button>
          <button type="submit" class="btn primary">${esc(submitLabel)}</button>
        </div>
      </form>`,
    onMount: (root, close) => {
      $('[data-x="cancel"]', root).onclick = close;
      $('form', root).onsubmit = (e) => {
        e.preventDefault();
        const data = Object.fromEntries(new FormData(e.target).entries());
        close();
        onSubmit(data);
      };
    },
  });
}

function resourceModal({ title, value = {}, onSubmit }) {
  promptModal({
    title,
    hint: 'Links open in a new tab. Anything you add here is stored with your progress.',
    fields: [
      { name: 'type', label: 'Type', type: 'select', value: value.type || 'read',
        options: [['read', '📖 Reading'], ['watch', '▶ Video'], ['practice', '⌨ Practice'], ['doc', '🔗 Other']] },
      { name: 'label', label: 'Label', value: value.label || value.title || '', placeholder: 'e.g. Refactoring Guru — Strategy', required: true },
      { name: 'url', label: 'URL', value: value.url || '', placeholder: 'https://…', required: true },
    ],
    onSubmit: (d) => {
      if (!safeUrl(d.url)) { toast('That URL is not a valid http(s) link', 'err'); return; }
      onSubmit(d);
    },
  });
}

const KIND_OPTIONS = [
  ['concept', '◆ Concept'], ['theory', '▤ Theory'], ['problem', '◈ Problem'],
  ['exercise', '✎ Exercise'], ['project', '★ Project'], ['note', '· Note'],
];

function topicModal({ title, value = {}, submitLabel, onSubmit }) {
  promptModal({
    title,
    hint: 'The body is markdown — headings, lists, tables, <code>```swift</code> code fences and <code>```mermaid</code> diagrams all render.',
    submitLabel,
    fields: [
      { name: 'title', label: 'Title', value: value.title || '', placeholder: 'e.g. Protocol witness tables', required: true },
      { name: 'kind', label: 'Kind', type: 'select', value: value.kind || 'concept', options: KIND_OPTIONS },
      { name: 'body', label: 'Body (markdown)', type: 'textarea', value: value.body || '', placeholder: 'What this topic is, and how to think about it…' },
    ],
    onSubmit,
  });
}

function themeModal() {
  modal({
    render: () => `
      <h3>Theme</h3>
      <p class="hint">Accent colour and light/dark mode. Saved with your profile.</p>
      <div class="row" style="margin-bottom:14px">
        <div class="seg">
          <button data-act="mode" data-v="light" aria-pressed="${state.prefs.mode === 'light'}">Light</button>
          <button data-act="mode" data-v="dark" aria-pressed="${state.prefs.mode === 'dark'}">Dark</button>
        </div>
      </div>
      <div class="theme-grid">
        ${THEMES.map(([id, label, c1, c2]) => `
          <button class="theme-opt" data-act="theme" data-v="${id}" aria-pressed="${state.prefs.theme === id}">
            <div class="theme-swatch" style="background:linear-gradient(135deg,${c1},${c2})"></div>
            <span>${label}</span>
          </button>`).join('')}
      </div>
      <div class="modal-actions"><button class="btn primary" data-x="done">Done</button></div>`,
    onMount: (root, close) => {
      $('[data-x="done"]', root).onclick = () => { close(); render(); };
      root.addEventListener('click', (e) => {
        const b = e.target.closest('[data-act]');
        if (!b) return;
        if (b.dataset.act === 'theme') setPref('theme', b.dataset.v);
        if (b.dataset.act === 'mode') setPref('mode', b.dataset.v);
        applyTheme();
        invalidateDiagrams();
        $$('[data-act="theme"]', root).forEach((x) => x.setAttribute('aria-pressed', x.dataset.v === state.prefs.theme));
        $$('[data-act="mode"]', root).forEach((x) => x.setAttribute('aria-pressed', x.dataset.v === state.prefs.mode));
      });
    },
  });
}

/* ------------------------------------------------------- notes editor */

/** Keep the inline textarea, the note indicator and storage in step. */
function writeNotes(id, text, statusEl) {
  if (statusEl) statusEl.textContent = 'saving…';
  notesSave(id, text, statusEl);
  const inline = $(`.item[data-id="${CSS.escape(id)}"] textarea[data-act="notes"]`);
  if (inline && inline.value !== text) inline.value = text;
}

/**
 * Full-screen note editor. Scrolling a 110px box to re-read a long note is
 * painful, so the same text gets a large pane with an optional preview.
 */
function openNotesModal(id, { append = '' } = {}) {
  const item = content.itemById.get(id);
  const start = notesOf(id);
  const seeded = append ? (start ? `${start.replace(/\s*$/, '')}\n\n${append}` : append) : start;

  modal({
    render: () => `
      <div class="notes-modal">
        <div class="nm-head">
          <div>
            <h3>Notes</h3>
            <p class="hint">${esc(item ? item.title : '')}</p>
          </div>
          <div class="row">
            <div class="seg">
              <button data-nm="write" aria-pressed="true">Write</button>
              <button data-nm="preview" aria-pressed="false">Preview</button>
            </div>
            <button class="btn" data-x="close">Done</button>
          </div>
        </div>
        <textarea class="nm-text" placeholder="What clicked, what tripped you up, the one-line rule you want to remember…">${esc(seeded)}</textarea>
        <div class="nm-preview md" hidden></div>
        <div class="nm-foot">
          <span class="muted" data-nm-status></span>
          <span class="spacer"></span>
          <span class="muted"><span data-nm-count>0</span> characters · markdown supported · saves as you type</span>
        </div>
      </div>`,
    onMount: (root, close) => {
      const ta = $('.nm-text', root);
      const preview = $('.nm-preview', root);
      const status = $('[data-nm-status]', root);
      const count = $('[data-nm-count]', root);
      const sync = () => { count.textContent = String(ta.value.length); };

      if (append) {
        ta.focus();
        ta.setSelectionRange(ta.value.length, ta.value.length);
        ta.scrollTop = ta.scrollHeight;
        writeNotes(id, ta.value, status);
      } else {
        ta.focus();
      }
      sync();

      ta.addEventListener('input', () => { sync(); writeNotes(id, ta.value, status); });

      $('[data-nm="write"]', root).onclick = () => {
        preview.hidden = true; ta.hidden = false;
        $('[data-nm="write"]', root).setAttribute('aria-pressed', 'true');
        $('[data-nm="preview"]', root).setAttribute('aria-pressed', 'false');
      };
      $('[data-nm="preview"]', root).onclick = () => {
        preview.innerHTML = renderMarkdown(ta.value || '_Nothing written yet._');
        enhance(preview);
        preview.hidden = false; ta.hidden = true;
        $('[data-nm="write"]', root).setAttribute('aria-pressed', 'false');
        $('[data-nm="preview"]', root).setAttribute('aria-pressed', 'true');
      };
      $('[data-x="close"]', root).onclick = () => {
        notesSave.flush(id, ta.value, null);
        close();
        patchCard(id);
      };
    },
  });
}

/* ------------------------------------------------- select text to annotate */
let selBtn = null;

function hideSelectionButton() {
  if (selBtn) { selBtn.remove(); selBtn = null; }
}

/** Trim a pasted-in quote so a note stays readable. */
function quoteOf(text) {
  const clean = text.replace(/\s+/g, ' ').trim();
  const cut = clean.length > 400 ? `${clean.slice(0, 400)}…` : clean;
  return `> ${cut}\n\n`;
}

function showSelectionButton(id, rect, text) {
  hideSelectionButton();
  selBtn = document.createElement('button');
  selBtn.className = 'sel-note-btn';
  selBtn.type = 'button';
  selBtn.textContent = '✎ Note this';
  selBtn.style.top = `${rect.bottom + window.scrollY + 8}px`;
  selBtn.style.left = `${Math.max(12, rect.left + window.scrollX)}px`;
  selBtn.onmousedown = (e) => e.preventDefault();   // keep the selection alive
  selBtn.onclick = () => {
    hideSelectionButton();
    openNotesModal(id, { append: quoteOf(text) });
  };
  document.body.appendChild(selBtn);
}

document.addEventListener('mouseup', (e) => {
  // mouseup can land on the document itself, which has no closest()
  const target = e.target && e.target.nodeType === 1 ? e.target : null;
  if (target && target.closest('.sel-note-btn')) return;
  setTimeout(() => {
    const sel = window.getSelection();
    const text = sel ? String(sel) : '';
    if (!text.trim() || !sel.rangeCount) { hideSelectionButton(); return; }
    const node = sel.anchorNode;
    const el = node && (node.nodeType === 1 ? node : node.parentElement);
    const host = el && el.closest('.md[data-annotatable]');
    const card = host && host.closest('.item[data-id]');
    if (!card) { hideSelectionButton(); return; }
    showSelectionButton(card.dataset.id, sel.getRangeAt(0).getBoundingClientRect(), text);
  }, 0);
});
document.addEventListener('scroll', hideSelectionButton, true);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') hideSelectionButton(); });

/* ------------------------------------------------------ reset flows */
function confirmResetAll() {
  confirmModal({
    title: 'Reset all progress?',
    body: 'Every tick is cleared. <b>Notes, tags, favourites, links and your own modules are kept.</b> This cannot be undone.',
    confirmLabel: 'Reset progress',
    danger: true,
    onConfirm: () => { resetProgress(null); toast('All progress reset — notes kept', 'ok'); },
  });
}

function confirmResetModule(modId) {
  const mod = content.moduleById.get(modId);
  confirmModal({
    title: `Reset “${mod.title}”?`,
    body: `Clears the ticks in Module ${mod.num} only. <b>Notes, tags, favourites and links are kept.</b>`,
    confirmLabel: 'Reset module',
    danger: true,
    onConfirm: () => { resetProgress(modId); toast(`Module ${mod.num} progress reset`, 'ok'); },
  });
}

function confirmEraseAll() {
  confirmModal({
    title: 'Erase everything?',
    body: 'Deletes progress <b>and</b> every note, tag, favourite, custom link and module you added. If you are connected to a Gist, the empty state is pushed there too.',
    confirmLabel: 'Erase everything',
    danger: true,
    onConfirm: () => { resetEverything(null); toast('All local data erased', 'ok'); },
  });
}

/* ----------------------------------------------------------- export */
function doExport() {
  const blob = new Blob([JSON.stringify(exportState(), null, 2)], { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `lld-dashboard-${new Date().toISOString().slice(0, 10)}.json`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
}

function doImport() {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = 'application/json,.json';
  input.onchange = async () => {
    const file = input.files && input.files[0];
    if (!file) return;
    try {
      const data = JSON.parse(await file.text());
      if (!data || typeof data !== 'object' || !data.items) throw new Error('not a dashboard backup');
      confirmModal({
        title: 'Replace current state?',
        body: 'The imported file replaces your current progress, notes, tags, links and custom modules in this browser.',
        confirmLabel: 'Import',
        danger: true,
        onConfirm: () => { hydrate(data); persist(); applyTheme(); render(); toast('Backup imported', 'ok'); },
      });
    } catch (e) {
      toast(`Import failed — ${e.message}`, 'err');
    }
  };
  input.click();
}

/* ------------------------------------------------------- sync chrome */
function renderSyncPill() {
  const chip = $('#syncTop');
  if (chip) {
    chip.dataset.state = G.gh.status;
    chip.title = G.gh.message;
    $('.sync-name', chip).textContent =
      G.gh.status === 'synced' ? `@${(G.gh.user && G.gh.user.login) || 'synced'}`
        : G.gh.status === 'syncing' ? 'Syncing'
          : G.gh.status === 'error' ? 'Error'
            : 'Local';
    const slot = $('.sync-ic', chip);
    const url = G.gh.user && G.gh.user.avatar;
    const img = slot.querySelector('img');
    if (url && !img) {
      const el = document.createElement('img');
      el.alt = ''; el.src = url;
      slot.appendChild(el);
    } else if (url && img) img.src = url;
    else if (img) img.remove();
  }

  const pill = $('#syncPill');
  pill.dataset.state = G.gh.status;
  const avatar = G.gh.user && G.gh.user.avatar;
  let dot = $('.dot', pill);
  if (avatar && dot.tagName !== 'IMG') {
    const img = document.createElement('img');
    img.className = 'dot avatar';
    img.alt = '';
    dot.replaceWith(img);
    dot = img;
  } else if (!avatar && dot.tagName === 'IMG') {
    const span = document.createElement('span');
    span.className = 'dot';
    dot.replaceWith(span);
    dot = span;
  }
  if (avatar) dot.src = avatar;

  $('.sync-text', pill).textContent =
    G.gh.status === 'synced' ? `@${(G.gh.user && G.gh.user.login) || 'synced'}`
      : G.gh.status === 'syncing' ? 'Syncing…'
        : G.gh.status === 'error' ? 'Sync error'
          : 'Local only';
  pill.title = G.gh.message;
}

async function connectFlow(token, gistId) {
  try {
    await G.connect(token, { gistId: gistId || null });
    render();
  } catch (e) {
    toast(G.errorText(e), 'err');
    render();
  }
}

/* -------------------------------------------------------- delegation */
const notesSave = debounce((id, val, statusEl) => {
  setNotes(id, val);
  if (statusEl) { statusEl.textContent = 'saved'; setTimeout(() => { statusEl.textContent = ''; }, 1400); }
}, 600);

function itemIdOf(el) {
  const card = el.closest('.item[data-id]');
  return card ? card.dataset.id : null;
}

function handleItemAction(act, el, e, id) {
  if (act === 'done') {
    e.preventDefault(); e.stopPropagation();
    const item = content.itemById.get(id);
    if (item && item.trackable) toggleDone(id);
    return true;
  }
  if (act === 'fav') { e.preventDefault(); e.stopPropagation(); toggleFav(id); return true; }
  if (act === 'collapse') {
    e.preventDefault(); e.stopPropagation();
    const card = el.closest('.item');
    openCard(card, false);
    card.scrollIntoView({ block: 'nearest' });
    return true;
  }
  if (act === 'open') {
    const btn = e.target.closest('button[data-act]');
    if (btn && btn.dataset.act !== 'open') return true;
    e.preventDefault();
    openCard(el.closest('.item'));
    return true;
  }
  if (act === 'add-tag') {
    e.preventDefault(); e.stopPropagation();
    promptModal({
      title: 'Add tag',
      fields: [{ name: 'tag', label: 'Tag', placeholder: 'e.g. revisit, weak-spot, interview', required: true }],
      onSubmit: (d) => addTag(id, d.tag),
    });
    return true;
  }
  if (act === 'edit-tag') {
    e.preventDefault(); e.stopPropagation();
    const from = el.dataset.tag;
    promptModal({
      title: 'Rename tag',
      hint: 'Renaming a built-in tag replaces it with your own for this item only.',
      fields: [{ name: 'tag', label: 'Tag', value: from, required: true }],
      onSubmit: (d) => renameTag(id, from, d.tag),
    });
    return true;
  }
  if (act === 'del-tag') { e.preventDefault(); e.stopPropagation(); removeTag(id, el.dataset.tag); return true; }
  if (act === 'expand-notes') { e.preventDefault(); e.stopPropagation(); openNotesModal(id); return true; }
  if (act === 'add-res') {
    e.preventDefault(); e.stopPropagation();
    resourceModal({ title: 'Add link', onSubmit: (d) => addResource(id, d) });
    return true;
  }
  if (act === 'edit-res') {
    e.preventDefault(); e.stopPropagation();
    const cur = resourcesOf(id).find((r) => r.id === el.dataset.res) || {};
    resourceModal({ title: 'Edit link', value: cur, onSubmit: (d) => updateResource(id, el.dataset.res, d) });
    return true;
  }
  if (act === 'del-res') { e.preventDefault(); e.stopPropagation(); removeResource(id, el.dataset.res); return true; }
  return false;
}

document.addEventListener('click', async (e) => {
  if (!e.target || e.target.nodeType !== 1) return;
  const el = e.target.closest('[data-act]');
  if (!el) return;
  const act = el.dataset.act;
  const id = itemIdOf(el);

  if (id && handleItemAction(act, el, e, id)) return;

  if (act === 'reveal') { e.preventDefault(); el.closest('.spoiler-shade').classList.add('revealed'); return; }
  if (act === 'goto-module') { e.preventDefault(); e.stopPropagation(); location.hash = `#/m/${el.dataset.mod}`; return; }
  if (act === 'goto-item') {
    e.preventDefault(); e.stopPropagation();
    const target = el.dataset.target;
    const m = content.itemModule.get(target);
    const s = content.itemSection.get(target);
    if (m && s) location.hash = `#/m/${m.id}/${s.id}/${encodeURIComponent(target)}`;
    return;
  }

  /* ---- links owned by a section or named explicitly ---- */
  if (act === 'edit-res-std' || act === 'del-res-std') {
    e.preventDefault(); e.stopPropagation();
    const targetId = el.dataset.id;
    if (act === 'del-res-std') { removeResource(targetId, el.dataset.res); return; }
    const cur = resourcesOf(targetId).find((r) => r.id === el.dataset.res) || {};
    resourceModal({ title: 'Edit link', value: cur, onSubmit: (d) => updateResource(targetId, el.dataset.res, d) });
    return;
  }
  if (act === 'add-section-res') {
    resourceModal({ title: 'Add link to this section', onSubmit: (d) => addResource(el.dataset.bucket, d) });
    return;
  }

  /* ---- global resources ---- */
  if (act === 'add-global-res') {
    resourceModal({ title: 'Add general resource', onSubmit: (d) => addGlobalResource({ type: d.type, title: d.label, label: d.label, url: d.url }) });
    return;
  }
  if (act === 'edit-global-res') {
    const cur = globalResources().find((r) => r.id === el.dataset.res) || {};
    resourceModal({ title: 'Edit resource', value: cur, onSubmit: (d) => updateGlobalResource(el.dataset.res, { type: d.type, title: d.label, label: d.label, url: d.url }) });
    return;
  }
  if (act === 'del-global-res') { removeGlobalResource(el.dataset.res); return; }

  /* ---- the user's own modules, sections and topics ---- */
  if (act === 'add-module') {
    promptModal({
      title: 'New module',
      hint: 'Your own module sits alongside the curriculum and counts towards overall progress.',
      fields: [{ name: 'title', label: 'Module name', placeholder: 'e.g. Distributed systems warm-ups', required: true }],
      submitLabel: 'Create module',
      onSubmit: (d) => { const m = addCustomModule({ title: d.title }); location.hash = `#/m/${m.id}`; toast('Module created', 'ok'); },
    });
    return;
  }
  if (act === 'add-section') {
    const modId = el.dataset.mod;
    promptModal({
      title: 'New section',
      fields: [
        { name: 'title', label: 'Section name', placeholder: 'e.g. Problems', required: true },
        { name: 'kind', label: 'Kind', type: 'select', value: 'concept', options: KIND_OPTIONS },
      ],
      submitLabel: 'Add section',
      onSubmit: (d) => { const s = addCustomSection({ moduleId: modId, title: d.title, kind: d.kind }); location.hash = `#/m/${modId}/${s.id}`; },
    });
    return;
  }
  if (act === 'add-topic') {
    const { mod, sec } = el.dataset;
    topicModal({
      title: 'New topic',
      submitLabel: 'Add topic',
      onSubmit: (d) => { addCustomItem({ moduleId: mod, sectionId: sec, title: d.title, kind: d.kind, body: d.body }); toast('Topic added', 'ok'); },
    });
    return;
  }
  if (act === 'edit-topic') {
    e.stopPropagation();
    const target = el.dataset.target;
    const cur = state.custom.items.find((x) => x.id === target) || {};
    topicModal({
      title: 'Edit topic',
      value: cur,
      submitLabel: 'Save topic',
      onSubmit: (d) => updateCustom('items', target, { title: d.title, kind: d.kind, body: d.body }),
    });
    return;
  }
  if (act === 'del-topic') {
    e.stopPropagation();
    const target = el.dataset.target;
    confirmModal({
      title: 'Delete this topic?',
      body: 'The topic and its notes, tags and links go with it.',
      confirmLabel: 'Delete', danger: true,
      onConfirm: () => { removeCustom('items', target); toast('Topic deleted', 'ok'); },
    });
    return;
  }
  if (act === 'del-section') {
    const secId = el.dataset.sec;
    confirmModal({
      title: 'Delete this section?',
      body: 'Every topic inside it is deleted too.',
      confirmLabel: 'Delete section', danger: true,
      onConfirm: () => { removeCustom('sections', secId); location.hash = `#/m/${route.moduleId}`; },
    });
    return;
  }
  if (act === 'del-module') {
    const modId = el.dataset.mod;
    confirmModal({
      title: 'Delete this module?',
      body: 'Every section and topic you put in it is deleted too.',
      confirmLabel: 'Delete module', danger: true,
      onConfirm: () => { removeCustom('modules', modId); location.hash = '#/'; },
    });
    return;
  }

  /* ---- resets ---- */
  if (act === 'reset-all') { confirmResetAll(); return; }
  if (act === 'reset-module') { confirmResetModule(el.dataset.mod); return; }
  if (act === 'erase-all') { confirmEraseAll(); return; }

  /* ---- settings ---- */
  if (act === 'theme') { setPref('theme', el.dataset.v); applyTheme(); invalidateDiagrams(); render(); return; }
  if (act === 'mode') { setPref('mode', el.dataset.v); applyTheme(); invalidateDiagrams(); render(); return; }
  if (act === 'spoiler') { setPref('revealSolutions', el.dataset.v === '1'); render(); return; }
  if (act === 'export') { doExport(); return; }
  if (act === 'import') { doImport(); return; }

  if (act === 'gist-connect') {
    const token = $('#tok') && $('#tok').value.trim();
    if (!token) { toast('Paste a token first', 'err'); return; }
    await connectFlow(token, $('#gid') && $('#gid').value.trim());
    return;
  }
  if (act === 'gist-pull') { await G.pull(); render(); return; }
  if (act === 'gist-push') { await G.pushNow(); toast('Pushed to Gist', 'ok'); return; }
  if (act === 'gist-disconnect') {
    confirmModal({
      title: 'Disconnect GitHub?',
      body: 'The token is removed from this browser. Your Gist and its data stay on GitHub — reconnect with the same token to pick up where you left off.',
      confirmLabel: 'Disconnect', danger: true,
      onConfirm: () => { G.disconnect(); render(); },
    });
    return;
  }

  /* ---- filters ---- */
  if (act === 'f-status') { filters.status = el.dataset.v; afterFilterChange(); return; }
  if (act === 'f-kind') { toggleSet(filters.kinds, el.dataset.v); afterFilterChange(); return; }
  if (act === 'f-diff') { toggleSet(filters.difficulty, el.dataset.v); afterFilterChange(); return; }
  if (act === 'f-fav') { filters.fav = !filters.fav; afterFilterChange(); return; }
  if (act === 'f-notes') { filters.notes = !filters.notes; afterFilterChange(); return; }
  if (act === 'f-tag') { toggleSet(filters.tags, el.dataset.v); afterFilterChange(); return; }
  if (act === 'f-clear') {
    filters.tags.clear(); filters.kinds.clear(); filters.difficulty.clear();
    filters.fav = false; filters.notes = false; filters.status = 'all';
    afterFilterChange();
    return;
  }
  if (act === 'filter-tag') {
    e.preventDefault(); e.stopPropagation();
    filters.tags.clear();
    filters.tags.add(el.dataset.tag);
    $('#filterBar').hidden = false;
    location.hash = '#/browse';
    afterFilterChange();
  }
});

function toggleSet(set, v) { if (set.has(v)) set.delete(v); else set.add(v); }

function afterFilterChange() {
  renderFilterBar();
  syncFilterChrome();
  if (route.name === 'module' || route.name === 'browse' || route.name === 'resources') render();
}

function syncFilterChrome() {
  const n = filtersActive();
  const badge = $('#filterCount');
  badge.hidden = n === 0;
  badge.textContent = String(n);
}

/* notes typing */
document.addEventListener('input', (e) => {
  if (!e.target || e.target.nodeType !== 1) return;
  const ta = e.target.closest('textarea[data-act="notes"]');
  if (!ta) return;
  const id = itemIdOf(ta);
  const status = ta.closest('.notes-wrap').querySelector('[data-notes-status]');
  if (status) status.textContent = 'saving…';
  notesSave(id, ta.value, status);
});

/* keyboard activation for the non-button controls */
document.addEventListener('keydown', (e) => {
  if ((e.key === 'Enter' || e.key === ' ') && e.target && e.target.nodeType === 1) {
    const el = e.target.closest('[data-act="filter-tag"], [data-act="goto-item"]');
    if (el) { e.preventDefault(); el.click(); }
  }
});

/* ------------------------------------------------------------ search */
const runSearch = debounce(() => {
  filters.q = $('#search').value.trim();
  $('#clearSearch').hidden = !filters.q;
  if (filters.q && route.name !== 'browse' && route.name !== 'module' && route.name !== 'resources') {
    location.hash = '#/browse';
  } else {
    render();
  }
}, 220);

/* ------------------------------------------------------------- boot */
async function boot() {
  loadLocal();
  applyTheme();
  try {
    await loadContent();
  } catch (e) {
    $('#boot').innerHTML = `<div class="boot-card"><p><b>Could not load the curriculum.</b></p>
      <p class="muted">${esc(e.message)} — serve this folder over HTTP (for example <code>python3 -m http.server</code>) rather than opening the file directly.</p></div>`;
    return;
  }

  $('#boot').remove();
  $('#app').hidden = false;

  $('#search').addEventListener('input', runSearch);
  $('#clearSearch').onclick = () => { $('#search').value = ''; runSearch.flush(); };
  $('#filterBtn').onclick = () => { const b = $('#filterBar'); b.hidden = !b.hidden; };
  $('#themeBtn').onclick = themeModal;
  $('#modeBtn').onclick = () => {
    setPref('mode', state.prefs.mode === 'dark' ? 'light' : 'dark');
    applyTheme(); invalidateDiagrams(); render();
  };
  $('#openNav').onclick = () => $('#app').classList.add('nav-open');
  $('#closeNav').onclick = () => $('#app').classList.remove('nav-open');
  $('#scrim').onclick = () => $('#app').classList.remove('nav-open');
  $('#syncPill').onclick = () => { location.hash = '#/settings'; };
  $('#syncTop').onclick = () => { location.hash = '#/settings'; };

  document.addEventListener('keydown', (e) => {
    if (e.key === '/' && !/input|textarea/i.test(e.target.tagName)) { e.preventDefault(); $('#search').focus(); }
    if (e.key === 'Escape' && document.activeElement === $('#search')) { $('#search').value = ''; runSearch.flush(); $('#search').blur(); }
  });

  window.addEventListener('hashchange', () => { $('#app').classList.remove('nav-open'); render(); });
  window.addEventListener('beforeunload', flushRemote);

  subscribe((detail) => {
    if (detail.bulk || detail.prefs) { render(); return; }
    if (detail.item) {
      if (!detail.quiet) { patchCard(detail.item); updateProgressUI(); }
      return;
    }
    render();
  });

  G.onSync(renderSyncPill);
  renderSyncPill();
  render();

  // Restoring a saved token can replace state, so it runs after first paint.
  G.restore().then((ok) => { if (ok) render(); });
}

boot();
