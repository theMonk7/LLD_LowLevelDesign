/* View renderers: dashboard, module, browse, resources, settings. */

import {
  content, state, isDone, isFav, notesOf, visibleTags, tagsOf, resourcesOf, globalResources,
  moduleProgress, sectionProgress, overallProgress, phaseProgress, countsByKind,
  recentlyDone, favourites, withNotes, nextUp, loadBodies, bodyOf,
} from './store.js';
import { renderMarkdown, enhance, stripMd } from './md.js';
import { $, $$, esc, pct, ringSvg, barHtml, timeAgo, fmtDate, safeUrl } from './util.js';
import { gh } from './gist.js';

export const THEMES = [
  ['indigo', 'Indigo', '#6366f1', '#8b5cf6'],
  ['violet', 'Violet', '#a855f7', '#6366f1'],
  ['emerald', 'Emerald', '#10b981', '#14b8a6'],
  ['cyan', 'Cyan', '#06b6d4', '#3b82f6'],
  ['amber', 'Amber', '#f59e0b', '#fb7185'],
  ['rose', 'Rose', '#f43f5e', '#ec4899'],
  ['nord', 'Nord', '#88c0d0', '#5e81ac'],
  ['slate', 'Slate', '#64748b', '#475569'],
];

export const KIND_META = {
  concept: { icon: '◆', label: 'Concept' },
  theory: { icon: '▤', label: 'Theory' },
  problem: { icon: '◈', label: 'Problem' },
  exercise: { icon: '✎', label: 'Exercise' },
  project: { icon: '★', label: 'Project' },
  solution: { icon: '🔒', label: 'Solution' },
  note: { icon: '·', label: 'Note' },
};

/* Shared, mutable filter state (the topbar writes it, views read it). */
export const filters = {
  q: '',
  tags: new Set(),
  status: 'all',      // all | todo | done
  fav: false,
  kinds: new Set(),
  difficulty: new Set(),
  notes: false,
};

export function filtersActive() {
  return filters.tags.size + filters.kinds.size + filters.difficulty.size
    + (filters.fav ? 1 : 0) + (filters.notes ? 1 : 0) + (filters.status !== 'all' ? 1 : 0);
}

export function matches(item) {
  if (filters.status === 'done' && !isDone(item.id)) return false;
  if (filters.status === 'todo' && isDone(item.id)) return false;
  if (filters.fav && !isFav(item.id)) return false;
  if (filters.notes && !notesOf(item.id).trim()) return false;
  if (filters.kinds.size && !filters.kinds.has(item.kind)) return false;
  if (filters.difficulty.size && !filters.difficulty.has(item.difficulty)) return false;
  if (filters.tags.size) {
    const t = tagsOf(item.id).map((x) => x.toLowerCase());
    for (const want of filters.tags) if (!t.includes(want.toLowerCase())) return false;
  }
  if (filters.q) {
    const mod = content.itemModule.get(item.id);
    const hay = `${item.title} ${item.kind} ${tagsOf(item.id).join(' ')} ${mod?.title || ''} ${notesOf(item.id)}`.toLowerCase();
    const terms = filters.q.toLowerCase().split(/\s+/).filter(Boolean);
    if (!terms.every((w) => hay.includes(w))) return false;
  }
  return true;
}

/* ------------------------------------------------------- components */

function tagChips(id, { editable = true } = {}) {
  const chips = visibleTags(id)
    .map(({ t, seed }) => `<span class="tag ${seed ? '' : 'accent'}">
        <span class="tag-text" data-act="filter-tag" data-tag="${esc(t)}" role="button" tabindex="0">${esc(t)}</span>
        ${editable ? `<button data-act="edit-tag" data-tag="${esc(t)}" title="Rename tag">✎</button>
        <button data-act="del-tag" data-tag="${esc(t)}" title="Remove tag">✕</button>` : ''}
      </span>`).join('');
  return `${chips}${editable ? '<button class="tag add" data-act="add-tag">+ tag</button>' : ''}`;
}

const RES_ICON = { read: '📖', watch: '▶', practice: '⌨', doc: '🔗' };

function resourceList(id) {
  const list = resourcesOf(id);
  if (!list.length) return '<p class="empty-note">No links yet — add a reading or video link.</p>';
  return `<div class="res-list">${list.map((r) => {
    const u = safeUrl(r.url);
    return `<div class="res" data-res="${esc(r.id)}">
      <span class="rtype">${RES_ICON[r.type] || '🔗'}</span>
      <a class="rlabel" href="${esc(u || '#')}" target="_blank" rel="noopener noreferrer">${esc(r.label || r.type)}</a>
      <span class="rurl">${esc((u || r.url || '').replace(/^https?:\/\//, ''))}</span>
      <span class="ract">
        <button class="ibtn" data-act="edit-res" data-res="${esc(r.id)}" title="Edit link">✎</button>
        <button class="ibtn" data-act="del-res" data-res="${esc(r.id)}" title="Remove link">✕</button>
      </span>
    </div>`;
  }).join('')}</div>`;
}

export function itemCard(item, { showModule = false, open = false } = {}) {
  const done = isDone(item.id);
  const fav = isFav(item.id);
  const mod = content.itemModule.get(item.id);
  const sec = content.itemSection.get(item.id);
  const km = KIND_META[item.kind] || KIND_META.note;
  const hasNotes = !!notesOf(item.id).trim();
  const resCount = resourcesOf(item.id).length;

  return `<article class="item ${done ? 'done' : ''} ${open ? 'open' : ''}" data-id="${esc(item.id)}"
    data-showmod="${showModule ? '1' : '0'}" id="i-${esc(item.id)}">
    <div class="item-head" data-act="open">
      <button class="tick ${item.trackable ? '' : 'na'}" data-act="done"
              title="${item.trackable ? 'Mark done' : 'Reference material — not tracked'}"
              aria-pressed="${done}">✓</button>
      <div class="item-main">
        <div class="item-title">${esc(item.title)}</div>
        <div class="item-sub">
          <span class="tag">${km.icon} ${km.label}</span>
          ${item.difficulty ? `<span class="tag ${item.difficulty}">${item.difficulty}</span>` : ''}
          ${showModule && mod ? `<span class="tag clickable" data-act="goto-module" data-mod="${esc(mod.id)}">M${esc(mod.num)} · ${esc(mod.title)}</span>` : ''}
          ${!showModule && sec?.spoiler ? '<span class="tag">spoiler</span>' : ''}
          ${resCount ? `<span class="tag">🔗 ${resCount}</span>` : ''}
          ${visibleTags(item.id).slice(0, showModule ? 2 : 5).map(({ t }) =>
            `<span class="tag clickable" data-act="filter-tag" data-tag="${esc(t)}">${esc(t)}</span>`).join('')}
        </div>
      </div>
      <div class="item-icons">
        ${hasNotes ? '<span class="ibtn note-on" title="Has notes">✎</span>' : ''}
        <button class="ibtn ${fav ? 'on' : ''}" data-act="fav" title="Favourite">${fav ? '★' : '☆'}</button>
        <button class="ibtn" data-act="open" title="Expand">▾</button>
      </div>
    </div>
    <div class="item-body" hidden></div>
  </article>`;
}

/** Fill an expanded card's body (markdown + tools). */
export async function fillItemBody(card) {
  const id = card.dataset.id;
  const body = card.querySelector('.item-body');
  if (body.dataset.filled === '1') return;

  const mod = content.itemModule.get(id);
  const sec = content.itemSection.get(id);
  body.innerHTML = '<p class="muted">Loading…</p>';
  try { await loadBodies(mod.id); } catch { /* fall through to empty */ }

  const md = bodyOf(id) || '_No content._';
  const spoiler = !!sec?.spoiler && !state.prefs.revealSolutions;
  const done = isDone(id);

  body.innerHTML = `
    ${spoiler ? '<div class="spoiler-shade"><div class="veil"><div><b>Solution / commentary</b><p class="muted">Attempt it first — then reveal.</p><button class="btn sm" data-act="reveal">Reveal</button></div></div>' : ''}
    <div class="md">${renderMarkdown(md)}</div>
    ${spoiler ? '</div>' : ''}

    <div class="item-tools">
      ${sec?.source ? `<span class="tag">source: ${esc(mod.slug)}/${esc(sec.source)}</span>` : ''}
      ${done ? `<span class="tag">done ${esc(fmtDate(state.items[id]?.doneAt))}</span>` : ''}
    </div>

    <h4 style="margin:16px 0 0;font-size:12px;letter-spacing:.07em;text-transform:uppercase;color:var(--tx3)">Tags</h4>
    <div class="item-sub" style="margin-top:7px">${tagChips(id)}</div>

    <h4 style="margin:16px 0 0;font-size:12px;letter-spacing:.07em;text-transform:uppercase;color:var(--tx3)">
      Reading &amp; videos
      <button class="btn sm" style="float:right;margin-top:-4px" data-act="add-res">+ Add link</button>
    </h4>
    ${resourceList(id)}

    <div class="notes-wrap">
      <div class="notes-head"><span>My notes</span><span class="muted" data-notes-status></span></div>
      <textarea data-act="notes" placeholder="What clicked, what tripped you up, the one-line rule you want to remember…">${esc(notesOf(id))}</textarea>
    </div>`;

  body.dataset.filled = '1';
  enhance(body);
}

export function refreshItemBodyBlocks(card) {
  const id = card.dataset.id;
  const body = card.querySelector('.item-body');
  if (!body || body.dataset.filled !== '1') return;
  const tagRow = body.querySelector('.item-sub');
  if (tagRow) tagRow.innerHTML = tagChips(id);
  const res = body.querySelector('.res-list, .empty-note');
  if (res) res.outerHTML = resourceList(id);
}

function groupItems(items) {
  const groups = new Map();
  for (const it of items) {
    const g = it.group || '';
    if (!groups.has(g)) groups.set(g, []);
    groups.get(g).push(it);
  }
  return groups;
}

/* --------------------------------------------------------- dashboard */
export function viewDashboard() {
  const o = overallProgress();
  const p = pct(o.done, o.total);
  const kinds = countsByKind();
  const next = nextUp();
  const modsDone = content.modules.filter((m) => { const x = moduleProgress(m); return x.total && x.done === x.total; }).length;
  const favs = favourites();
  const notes = withNotes();
  const recent = recentlyDone(6);

  const kindCards = ['concept', 'theory', 'problem', 'exercise', 'project']
    .filter((k) => kinds[k])
    .map((k) => {
      const c = kinds[k];
      return `<div class="card stat">
        <div class="k">${KIND_META[k].icon} ${KIND_META[k].label}s</div>
        <div class="v">${c.done}<small> / ${c.total}</small></div>
        ${barHtml(pct(c.done, c.total), pct(c.done, c.total) === 100 ? 'ok' : '')}
      </div>`;
    }).join('');

  const phases = content.data.phases.map((ph) => {
    const pp = phaseProgress(ph.id);
    const mods = content.modules.filter((m) => m.phaseId === ph.id);
    return `
    <div class="phase-head">
      <h2>${esc(ph.title)}</h2>
      ${barHtml(pct(pp.done, pp.total), pct(pp.done, pp.total) === 100 ? 'ok' : '')}
      <span class="muted">${pp.done}/${pp.total}</span>
    </div>
    <div class="grid mods">${mods.map(moduleCard).join('')}</div>`;
  }).join('');

  return `
  <section class="hero">
    <div class="big-ring">${ringSvg(p, 108, 9)}</div>
    <div class="hero-body">
      <div class="eyebrow">Low Level Design · Swift</div>
      <h1>${p === 100 ? 'Curriculum complete 🎉' : 'Your learning dashboard'}</h1>
      <p class="sub">${o.done} of ${o.total} tracked items done across ${content.modules.length} modules.
      ${next ? `Next up: <a href="#/m/${next.module.id}/${encodeURIComponent(next.item.id)}"><b>${esc(next.item.title)}</b></a> in M${esc(next.module.num)}.` : 'Nothing left in the queue.'}</p>
      <div class="hero-actions">
        ${next ? `<a class="btn primary" href="#/m/${next.module.id}/${encodeURIComponent(next.item.id)}">Continue learning →</a>` : ''}
        <a class="btn" href="#/browse">Browse everything</a>
        <a class="btn" href="#/resources">Reading &amp; videos</a>
        <button class="btn danger" data-act="reset-all">Reset progress</button>
      </div>
    </div>
  </section>

  <div class="grid stats">
    <div class="card stat"><div class="k">Modules finished</div><div class="v">${modsDone}<small> / ${content.modules.length}</small></div>
      ${barHtml(pct(modsDone, content.modules.length))}</div>
    ${kindCards}
    <div class="card stat"><div class="k">Favourites</div><div class="v">${favs.length}</div>
      <div class="m"><a href="#/browse?fav=1">review starred items</a></div></div>
    <div class="card stat"><div class="k">Items with notes</div><div class="v">${notes.length}</div>
      <div class="m"><a href="#/browse?notes=1">open my notes</a></div></div>
  </div>

  ${recent.length ? `
  <h2 class="sec">Recently completed <span class="count">last ${recent.length}</span></h2>
  <div class="items">${recent.map((r) => `
    <a class="item" style="display:block" href="#/m/${r.module.id}/${encodeURIComponent(r.id)}">
      <div class="item-head">
        <span class="tick" style="background:var(--ok);border-color:var(--ok);color:#fff">✓</span>
        <div class="item-main">
          <div class="item-title">${esc(r.item.title)}</div>
          <div class="item-sub"><span class="tag">M${esc(r.module.num)} · ${esc(r.module.title)}</span><span class="muted">${esc(timeAgo(r.at))}</span></div>
        </div>
      </div></a>`).join('')}
  </div>` : ''}

  ${phases}`;
}

function moduleCard(m) {
  const p = moduleProgress(m);
  const v = pct(p.done, p.total);
  const complete = p.total && p.done === p.total;
  const probs = m.sections.find((s) => s.id === 'problems');
  return `<a class="card mod-card ${complete ? 'done' : ''}" href="#/m/${m.id}">
    <div class="mc-top">
      <span class="mc-num">M${esc(m.num)}</span>
      <span class="mc-title">${esc(m.title)}</span>
      ${complete ? '<span class="mc-check">✓</span>' : ''}
    </div>
    <div class="mc-meta">
      <span>${m.sections.length} sections</span>
      ${probs ? `<span>${probs.items.length} problems</span>` : ''}
      ${m.difficulty ? `<span class="tag ${m.difficulty}">${m.difficulty}</span>` : ''}
    </div>
    <div class="bar-row">${barHtml(v, complete ? 'ok' : '')}<span class="pct">${p.done}/${p.total} · ${v}%</span></div>
  </a>`;
}

/* ------------------------------------------------------------ module */
export function viewModule(mod, focusId = null) {
  const p = moduleProgress(mod);
  const v = pct(p.done, p.total);
  const anyFilter = filters.q || filtersActive();

  const sections = mod.sections.map((sec) => {
    const sp = sectionProgress(sec);
    const visible = sec.items.filter((it) => !anyFilter || matches(it));
    const key = `${mod.id}:${sec.id}`;
    const collapsed = state.prefs.collapsed[key] === true && !anyFilter;
    if (anyFilter && !visible.length) return '';

    const groups = groupItems(visible);
    const inner = [...groups.entries()].map(([g, items]) => `
      <div class="group-wrap">
        ${g ? `<div class="group-label">${esc(g)} <span class="muted">· ${items.length}</span></div>` : ''}
        <div class="items">${items.map((it) => itemCard(it, { open: it.id === focusId })).join('')}</div>
      </div>`).join('');

    return `<section class="sec-block" data-section="${esc(sec.id)}">
      <div class="sec-bar" data-act="toggle-section" data-key="${esc(key)}" aria-expanded="${!collapsed}" role="button" tabindex="0">
        <span class="caret">▾</span>
        <h3>${esc(sec.title)}</h3>
        <span class="src">${esc(sec.source)}</span>
        <span class="spacer"></span>
        ${sp.total ? `<span class="mini">${barHtml(pct(sp.done, sp.total), sp.done === sp.total ? 'ok' : 'thin')}</span>
          <span class="muted">${sp.done}/${sp.total}</span>` : '<span class="muted">reference</span>'}
      </div>
      <div class="sec-content" ${collapsed ? 'hidden' : ''}>${inner}</div>
    </section>`;
  }).join('');

  return `
  <div class="page-head">
    <div class="crumbs"><a href="#/">Dashboard</a> <span>/</span> <span>Module ${esc(mod.num)}</span></div>
    <div class="spread">
      <div>
        <div class="eyebrow">${esc(content.data.phases.find((x) => x.id === mod.phaseId)?.title || '')}</div>
        <h1>${esc(mod.title)}</h1>
      </div>
      <div class="row">
        <button class="btn sm" data-act="expand-all">Expand all</button>
        <button class="btn sm" data-act="collapse-all">Collapse all</button>
        <button class="btn sm danger" data-act="reset-module" data-mod="${esc(mod.id)}">Reset module</button>
      </div>
    </div>
    <div class="bar-row" style="margin-top:14px">
      ${barHtml(v, v === 100 ? 'ok' : '')}<span class="pct">${p.done}/${p.total} · ${v}%</span>
    </div>
  </div>
  ${anyFilter ? '<p class="muted">Filters are on — sections show only matching items.</p>' : ''}
  ${sections || '<div class="empty-state"><div class="big">🔍</div><p>No items in this module match the current filters.</p></div>'}`;
}

/* ------------------------------------------------------------ browse */
export function viewBrowse() {
  const hits = content.allItems.filter(matches);
  const byModule = new Map();
  for (const it of hits) {
    const m = content.itemModule.get(it.id);
    if (!byModule.has(m.id)) byModule.set(m.id, { m, items: [] });
    byModule.get(m.id).items.push(it);
  }

  const body = byModule.size
    ? [...byModule.values()].map(({ m, items }) => `
      <h2 class="sec"><a href="#/m/${m.id}">M${esc(m.num)} · ${esc(m.title)}</a> <span class="count">${items.length}</span></h2>
      <div class="items">${items.map((it) => itemCard(it, { showModule: false })).join('')}</div>`).join('')
    : '<div class="empty-state"><div class="big">🔍</div><p>Nothing matches. Loosen a filter or clear the search.</p></div>';

  return `
  <div class="page-head">
    <div class="eyebrow">Browse</div>
    <h1>${hits.length} item${hits.length === 1 ? '' : 's'}${filters.q ? ` for “${esc(filters.q)}”` : ''}</h1>
    <p class="sub">Everything in the curriculum, filtered by the controls above. Tick, star, tag and annotate from here.</p>
  </div>
  ${body}`;
}

/* --------------------------------------------------------- resources */
export function viewResources() {
  const q = filters.q.toLowerCase();
  const rows = [];
  for (const m of content.modules) {
    for (const s of m.sections) {
      for (const it of s.items) {
        const rs = resourcesOf(it.id);
        if (!rs.length) continue;
        const keep = rs.filter((r) => !q || `${r.label} ${r.url} ${it.title} ${m.title}`.toLowerCase().includes(q));
        if (keep.length) rows.push({ m, it, rs: keep });
      }
    }
  }
  const globals = globalResources().filter((r) => !q || `${r.title} ${r.url}`.toLowerCase().includes(q));
  const total = rows.reduce((a, r) => a + r.rs.length, 0) + globals.length;

  return `
  <div class="page-head">
    <div class="eyebrow">Library</div>
    <h1>Reading &amp; videos <span class="muted">· ${total} links</span></h1>
    <p class="sub">Seeded from the <a href="https://krucible.netlify.app/" target="_blank" rel="noopener noreferrer">Krucible LLD sheet</a> and attached to the matching concept or problem. Add your own anywhere; edits and additions sync with your progress.</p>
  </div>

  <h2 class="sec">General resources <span class="count">${globals.length}</span>
    <button class="btn sm" data-act="add-global-res">+ Add</button></h2>
  <div class="res-list">
    ${globals.map((r) => {
      const u = safeUrl(r.url);
      return `<div class="res">
        <span class="rtype">${RES_ICON[r.type] || '🔗'}</span>
        <a class="rlabel" href="${esc(u || '#')}" target="_blank" rel="noopener noreferrer">${esc(r.title || r.label)}</a>
        <span class="rurl">${esc((u || '').replace(/^https?:\/\//, ''))}</span>
        <span class="ract">
          <button class="ibtn" data-act="edit-global-res" data-res="${esc(r.id)}" title="Edit">✎</button>
          <button class="ibtn" data-act="del-global-res" data-res="${esc(r.id)}" title="Remove">✕</button>
        </span></div>`;
    }).join('') || '<p class="empty-note">No general links.</p>'}
  </div>

  ${rows.length ? rows.map(({ m, it, rs }) => `
    <div class="card" style="padding:13px 15px;margin-top:10px">
      <div class="spread">
        <div><a href="#/m/${m.id}/${encodeURIComponent(it.id)}"><b>${esc(it.title)}</b></a>
          <div class="muted">M${esc(m.num)} · ${esc(m.title)}</div></div>
        ${isDone(it.id) ? '<span class="tag" style="color:var(--ok)">done</span>' : ''}
      </div>
      <div class="res-list" data-id="${esc(it.id)}">
        ${rs.map((r) => {
          const u = safeUrl(r.url);
          return `<div class="res" data-res="${esc(r.id)}">
            <span class="rtype">${RES_ICON[r.type] || '🔗'}</span>
            <a class="rlabel" href="${esc(u || '#')}" target="_blank" rel="noopener noreferrer">${esc(r.label || r.type)}</a>
            <span class="rurl">${esc((u || '').replace(/^https?:\/\//, ''))}</span>
            <span class="ract">
              <button class="ibtn" data-act="edit-res-std" data-id="${esc(it.id)}" data-res="${esc(r.id)}" title="Edit">✎</button>
              <button class="ibtn" data-act="del-res-std" data-id="${esc(it.id)}" data-res="${esc(r.id)}" title="Remove">✕</button>
            </span></div>`;
        }).join('')}
      </div>
    </div>`).join('') : '<p class="empty-note" style="margin-top:14px">No item links match that search.</p>'}`;
}

/* ---------------------------------------------------------- settings */
export function viewSettings() {
  const o = overallProgress();
  const connected = !!gh.token;
  return `
  <div class="page-head">
    <div class="eyebrow">Settings</div>
    <h1>Settings &amp; sync</h1>
  </div>

  <section class="card" style="padding:18px;margin-bottom:16px">
    <div class="spread"><h2 class="sec" style="margin:0">Cross-browser sync (GitHub Gist)</h2>
      <span class="tag ${connected ? 'accent' : ''}">${connected ? `connected as @${esc(gh.user?.login || '')}` : 'not connected'}</span></div>
    <p class="sub" style="margin-top:8px">Your token is your account. A different token means a different private Gist — and therefore a separate set of progress, notes, tags and links.</p>

    <div class="warn-box" style="margin-top:12px">
      <b>Security:</b> the token is kept in this browser's <code>localStorage</code> and sent only to <code>api.github.com</code>.
      Use a token scoped to <b>gist only</b> (classic: <code>gist</code>; fine-grained: Account permissions → Gists → Read&nbsp;and&nbsp;write).
      Anyone with access to this browser profile can read it. Revoke it in GitHub settings if the machine is shared.
    </div>

    ${connected ? `
      <div class="row">
        <button class="btn" data-act="gist-pull">Pull from Gist</button>
        <button class="btn" data-act="gist-push">Push now</button>
        <a class="btn" href="https://gist.github.com/${esc(gh.gistId || '')}" target="_blank" rel="noopener noreferrer">Open Gist</a>
        <button class="btn danger" data-act="gist-disconnect">Disconnect &amp; forget token</button>
      </div>
      <p class="muted" style="margin-top:10px">Gist <code>${esc(gh.gistId || '—')}</code> · last sync ${esc(timeAgo(gh.lastSync))} · ${esc(gh.message)}</p>
    ` : `
      <div class="field"><label for="tok">GitHub personal access token</label>
        <input id="tok" type="password" placeholder="ghp_… or github_pat_…" autocomplete="off" /></div>
      <div class="field"><label for="gid">Existing Gist ID (optional — leave blank to find or create one)</label>
        <input id="gid" type="text" placeholder="e.g. 8f14e45fceea167a5a36dedd4bea2543" autocomplete="off" /></div>
      <div class="row">
        <button class="btn primary" data-act="gist-connect">Connect</button>
        <a class="btn" href="https://github.com/settings/tokens/new?scopes=gist&description=LLD%20Dashboard" target="_blank" rel="noopener noreferrer">Create a token →</a>
      </div>`}
  </section>

  <section class="card" style="padding:18px;margin-bottom:16px">
    <h2 class="sec" style="margin:0 0 12px">Appearance</h2>
    <div class="row" style="margin-bottom:14px">
      <span class="muted">Mode</span>
      <div class="seg">
        <button data-act="mode" data-v="light" aria-pressed="${state.prefs.mode === 'light'}">Light</button>
        <button data-act="mode" data-v="dark" aria-pressed="${state.prefs.mode === 'dark'}">Dark</button>
      </div>
      <span class="muted" style="margin-left:14px">Solutions</span>
      <div class="seg">
        <button data-act="spoiler" data-v="0" aria-pressed="${!state.prefs.revealSolutions}">Hide by default</button>
        <button data-act="spoiler" data-v="1" aria-pressed="${!!state.prefs.revealSolutions}">Always show</button>
      </div>
    </div>
    <div class="theme-grid">
      ${THEMES.map(([id, label, c1, c2]) => `
        <button class="theme-opt" data-act="theme" data-v="${id}" aria-pressed="${state.prefs.theme === id}">
          <div class="theme-swatch" style="background:linear-gradient(135deg,${c1},${c2})"></div>
          <span>${label}</span>
        </button>`).join('')}
    </div>
  </section>

  <section class="card" style="padding:18px;margin-bottom:16px">
    <h2 class="sec" style="margin:0 0 10px">Backup</h2>
    <p class="sub">A plain JSON file with every tick, note, tag and link — independent of GitHub.</p>
    <div class="row" style="margin-top:10px">
      <button class="btn" data-act="export">Export JSON</button>
      <button class="btn" data-act="import">Import JSON</button>
    </div>
  </section>

  <section class="card" style="padding:18px">
    <h2 class="sec" style="margin:0 0 10px">Danger zone</h2>
    <p class="sub">“Reset progress” clears completion only — <b>notes, tags, favourites and links are kept</b>. “Erase everything” removes all of it.</p>
    <div class="row" style="margin-top:12px">
      <button class="btn danger" data-act="reset-all">Reset all progress (${o.done} ticks)</button>
      <button class="btn danger" data-act="erase-all">Erase everything</button>
    </div>
  </section>

  <p class="muted" style="margin-top:22px">
    ${content.data.stats.items} items · ${content.data.stats.trackable} trackable · ${content.data.stats.seededLinks} seeded links ·
    content generated ${esc(new Date(content.data.generatedAt).toLocaleString())}
  </p>`;
}

/* ------------------------------------------------------- side panels */
export function renderSidebarProgress() {
  const o = overallProgress();
  const v = pct(o.done, o.total);
  $('#sideProgress').innerHTML = `
    <div class="ring-row">
      ${ringSvg(v, 58, 6)}
      <div class="ring-meta"><b>${o.done} / ${o.total}</b><span>items completed</span></div>
    </div>`;
}

export function renderSidebarModules(activeId) {
  $('#sideModules').innerHTML = content.modules.map((m) => {
    const p = moduleProgress(m);
    const v = pct(p.done, p.total);
    const complete = p.total && p.done === p.total;
    return `<a class="side-mod ${m.id === activeId ? 'active' : ''} ${complete ? 'done' : ''}" href="#/m/${m.id}">
      <div class="sm-top">
        <span class="sm-num">${esc(m.num)}</span>
        <span class="sm-title">${esc(m.title)}</span>
        <span class="sm-count">${p.done}/${p.total}</span>
      </div>
      <div class="sm-bar"><i style="width:${v}%"></i></div>
    </a>`;
  }).join('');
}

export function renderFilterBar() {
  const allTags = new Set(content.builtinTags);
  for (const id of Object.keys(state.items)) (state.items[id].tags || []).forEach((t) => allTags.add(t));
  const tagList = [...allTags].sort((a, b) => a.localeCompare(b));

  $('#filterBar').innerHTML = `
    <div class="fgroup"><label>Status</label>
      <div class="seg">
        ${['all', 'todo', 'done'].map((s) => `<button data-act="f-status" data-v="${s}" aria-pressed="${filters.status === s}">${s}</button>`).join('')}
      </div>
    </div>
    <div class="fgroup"><label>Kind</label>
      ${['concept', 'theory', 'problem', 'exercise', 'project', 'solution'].map((k) =>
        `<button class="tag clickable ${filters.kinds.has(k) ? 'accent' : ''}" data-act="f-kind" data-v="${k}">${KIND_META[k].icon} ${KIND_META[k].label}</button>`).join('')}
    </div>
    <div class="fgroup"><label>Difficulty</label>
      ${['easy', 'medium', 'hard'].map((d) =>
        `<button class="tag clickable ${filters.difficulty.has(d) ? 'accent' : ''} ${d}" data-act="f-diff" data-v="${d}">${d}</button>`).join('')}
    </div>
    <div class="fgroup"><label>Only</label>
      <button class="tag clickable ${filters.fav ? 'accent' : ''}" data-act="f-fav">★ favourites</button>
      <button class="tag clickable ${filters.notes ? 'accent' : ''}" data-act="f-notes">✎ has notes</button>
    </div>
    <div class="fgroup" style="flex:1 1 100%"><label>Tags</label>
      ${tagList.map((t) => `<button class="tag clickable ${filters.tags.has(t) ? 'accent' : ''}" data-act="f-tag" data-v="${esc(t)}">${esc(t)}</button>`).join('')}
      ${filtersActive() ? '<button class="btn sm" data-act="f-clear">Clear filters</button>' : ''}
    </div>`;
}

export { stripMd };
