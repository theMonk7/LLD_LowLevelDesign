/* View renderers: dashboard, module, browse, resources, settings. */

import {
  content, state, isDone, isFav, notesOf, visibleTags, tagsOf, resourcesOf, globalResources,
  moduleProgress, sectionProgress, overallProgress, phaseProgress, countsByKind,
  recentlyDone, favourites, withNotes, nextUp, loadBodies, bodyOf, CUSTOM_PHASE,
} from './store.js';
import { renderMarkdown, enhance, stripMd } from './md.js';
import { $, esc, pct, ringSvg, barHtml, timeAgo, fmtDate, safeUrl } from './util.js';
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

const RES_ICON = { read: '📖', watch: '▶', practice: '⌨', doc: '🔗' };

/** Links attached to a whole section rather than to one item. */
export const sectionBucket = (modId, secId) => `sec:${modId}:${secId}`;

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

function tagChips(id) {
  const chips = visibleTags(id)
    .map(({ t, seed }) => `<span class="tag ${seed ? '' : 'accent'}">
        <span class="tag-text" data-act="filter-tag" data-tag="${esc(t)}" role="button" tabindex="0">${esc(t)}</span>
        <button data-act="edit-tag" data-tag="${esc(t)}" title="Rename tag">✎</button>
        <button data-act="del-tag" data-tag="${esc(t)}" title="Remove tag">✕</button>
      </span>`).join('');
  return `${chips}<button class="tag add" data-act="add-tag">+ tag</button>`;
}

function resourceList(id) {
  const list = resourcesOf(id);
  if (!list.length) return '<p class="empty-note">No links yet — add a reading or video link.</p>';
  return `<div class="res-list">${list.map((r) => {
    const u = safeUrl(r.url);
    return `<div class="res" data-res="${esc(r.id)}">
      <span class="rtype">${RES_ICON[r.type] || '🔗'}</span>
      <a class="rlabel" href="${esc(u || '#')}" target="_blank" rel="noopener noreferrer">${esc(r.label || r.title || r.type)}</a>
      <span class="rurl">${esc((u || r.url || '').replace(/^https?:\/\//, ''))}</span>
      <span class="ract">
        <button class="ibtn" data-act="edit-res" data-res="${esc(r.id)}" title="Edit link">✎</button>
        <button class="ibtn" data-act="del-res" data-res="${esc(r.id)}" title="Remove link">✕</button>
      </span>
    </div>`;
  }).join('')}</div>`;
}

/** Every link under a section: the section's own bucket plus each item's. */
export function sectionLinks(mod, sec) {
  const own = resourcesOf(sectionBucket(mod.id, sec.id)).map((r) => ({ r, item: null }));
  const fromItems = sec.items.flatMap((it) => resourcesOf(it.id).map((r) => ({ r, item: it })));
  return [...own, ...fromItems];
}

function linkCountChips(links) {
  const read = links.filter((x) => x.r.type === 'read' || x.r.type === 'doc').length;
  const watch = links.filter((x) => x.r.type === 'watch').length;
  const practice = links.filter((x) => x.r.type === 'practice').length;
  return [
    read ? `<span class="tag link-chip">📖 ${read}</span>` : '',
    watch ? `<span class="tag link-chip">▶ ${watch}</span>` : '',
    practice ? `<span class="tag link-chip">⌨ ${practice}</span>` : '',
  ].join('');
}

function ownedLinkRow(r, ownerId, label) {
  return `<div class="res" data-res="${esc(r.id)}">
    <span class="rtype">${RES_ICON[r.type] || '🔗'}</span>
    <a class="rlabel" href="${esc(safeUrl(r.url) || '#')}" target="_blank" rel="noopener noreferrer">${esc(r.label || r.title || r.type)}</a>
    ${label}
    <span class="ract">
      <button class="ibtn" data-act="edit-res-std" data-id="${esc(ownerId)}" data-res="${esc(r.id)}" title="Edit link">✎</button>
      <button class="ibtn" data-act="del-res-std" data-id="${esc(ownerId)}" data-res="${esc(r.id)}" title="Remove link">✕</button>
    </span>
  </div>`;
}

function sectionLinkPanel(mod, sec) {
  const links = sectionLinks(mod, sec);
  const bucket = sectionBucket(mod.id, sec.id);
  const rows = links.map(({ r, item }) => ownedLinkRow(
    r,
    item ? item.id : bucket,
    item
      ? `<span class="res-owner" data-act="goto-item" data-target="${esc(item.id)}" role="button" tabindex="0">${esc(item.title)}</span>`
      : '<span class="res-owner muted">whole section</span>',
  )).join('');

  return `<details class="link-panel"${links.length ? '' : ' open'}>
    <summary>Reading &amp; videos in this section <span class="muted">· ${links.length}</span></summary>
    <div class="res-list">${rows || '<p class="empty-note">No links here yet.</p>'}</div>
    <button class="btn sm" data-act="add-section-res" data-bucket="${esc(bucket)}">+ Add link to this section</button>
  </details>`;
}

export function itemCard(item, { showModule = false, open = false } = {}) {
  const done = isDone(item.id);
  const fav = isFav(item.id);
  const mod = content.itemModule.get(item.id);
  const sec = content.itemSection.get(item.id);
  const km = KIND_META[item.kind] || KIND_META.note;
  const hasNotes = !!notesOf(item.id).trim();
  const links = resourcesOf(item.id);

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
          ${item.custom ? '<span class="tag accent">mine</span>' : ''}
          ${item.difficulty ? `<span class="tag ${item.difficulty}">${item.difficulty}</span>` : ''}
          ${showModule && mod ? `<span class="tag clickable" data-act="goto-module" data-mod="${esc(mod.id)}">M${esc(mod.num)} · ${esc(mod.title)}</span>` : ''}
          ${!showModule && sec?.spoiler ? '<span class="tag">spoiler</span>' : ''}
          ${links.map((r) => `<a class="tag link-chip" href="${esc(safeUrl(r.url) || '#')}" target="_blank" rel="noopener noreferrer"
              title="${esc(r.label || r.type)}">${RES_ICON[r.type] || '🔗'}</a>`).join('')}
          ${visibleTags(item.id).slice(0, showModule ? 2 : 5).map(({ t }) =>
            `<span class="tag clickable" data-act="filter-tag" data-tag="${esc(t)}">${esc(t)}</span>`).join('')}
        </div>
      </div>
      <div class="item-icons">
        ${hasNotes ? '<span class="ibtn note-on" title="Has notes">✎</span>' : ''}
        <button class="ibtn ${fav ? 'on' : ''}" data-act="fav" title="Favourite">${fav ? '★' : '☆'}</button>
        <button class="ibtn caret-btn" data-act="open" title="Expand">▾</button>
      </div>
    </div>
    <div class="item-body" hidden></div>
  </article>`;
}

function doneButtonLabel(id) {
  if (!isDone(id)) return 'Mark as completed';
  const at = state.items[id]?.doneAt;
  return `✓ Completed${at ? ` · ${fmtDate(at)}` : ''} — undo`;
}

/** Fill an expanded card's body: content, tools, then the actions at the end. */
export async function fillItemBody(card) {
  const id = card.dataset.id;
  const body = card.querySelector('.item-body');
  if (body.dataset.filled === '1') return;

  const item = content.itemById.get(id);
  const mod = content.itemModule.get(id);
  const sec = content.itemSection.get(id);
  body.innerHTML = '<p class="muted">Loading…</p>';
  try { await loadBodies(mod.id); } catch { /* fall through to empty */ }

  const md = bodyOf(id) || '_No content yet._';
  const spoiler = !!sec?.spoiler && !state.prefs.revealSolutions;

  body.innerHTML = `
    ${spoiler ? '<div class="spoiler-shade"><div class="veil"><div><b>Solution / commentary</b><p class="muted">Attempt it first — then reveal.</p><button class="btn sm" data-act="reveal">Reveal</button></div></div>' : ''}
    <div class="md">${renderMarkdown(md)}</div>
    ${spoiler ? '</div>' : ''}

    <div class="item-tools">
      ${sec?.source && sec.source !== 'mine' ? `<span class="tag">source: ${esc(mod.slug || mod.title)}/${esc(sec.source)}</span>` : ''}
      ${item?.custom ? '<span class="tag accent">your topic</span>' : ''}
    </div>

    <h4 class="sub-label">Tags</h4>
    <div class="item-sub">${tagChips(id)}</div>

    <h4 class="sub-label">Reading &amp; videos
      <button class="btn sm" data-act="add-res">+ Add link</button>
    </h4>
    ${resourceList(id)}

    <div class="notes-wrap">
      <div class="notes-head"><span>My notes</span><span class="muted" data-notes-status></span></div>
      <textarea data-act="notes" placeholder="What clicked, what tripped you up, the one-line rule you want to remember…">${esc(notesOf(id))}</textarea>
    </div>

    <div class="item-foot">
      ${item?.trackable
        ? `<button class="btn ${isDone(id) ? '' : 'primary'} done-btn" data-act="done">${esc(doneButtonLabel(id))}</button>`
        : '<span class="muted">Reference material — not tracked</span>'}
      ${item?.custom ? `<button class="btn sm" data-act="edit-topic" data-target="${esc(id)}">Edit topic</button>
        <button class="btn sm danger" data-act="del-topic" data-target="${esc(id)}">Delete</button>` : ''}
      <span class="spacer"></span>
      <button class="btn sm" data-act="collapse">Collapse ▴</button>
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

  const btn = body.querySelector('.done-btn');
  if (btn) {
    btn.classList.toggle('primary', !isDone(id));
    btn.textContent = doneButtonLabel(id);
  }
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

const allPhases = () => [...content.data.phases, { id: CUSTOM_PHASE, title: 'My modules' }];

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
  const nextHref = next ? `#/m/${next.module.id}/${next.section.id}/${encodeURIComponent(next.item.id)}` : '#/';

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

  const phases = allPhases().map((ph) => {
    const mods = content.modules.filter((m) => m.phaseId === ph.id);
    const custom = ph.id === CUSTOM_PHASE;
    if (!mods.length && !custom) return '';
    const pp = phaseProgress(ph.id);
    return `
    <div class="phase-head">
      <h2>${esc(ph.title)}</h2>
      ${barHtml(pct(pp.done, pp.total), pct(pp.done, pp.total) === 100 ? 'ok' : '')}
      <span class="muted">${pp.done}/${pp.total}</span>
      ${custom ? '<button class="btn sm" data-act="add-module">+ New module</button>' : ''}
    </div>
    <div class="grid mods">
      ${mods.map(moduleCard).join('')}
      ${custom && !mods.length
        ? `<button class="card mod-card add-card" data-act="add-module">
             <span class="plus">+</span><span class="mc-title">Add your own module</span>
             <span class="muted">Group topics the curriculum does not cover</span></button>`
        : ''}
    </div>`;
  }).join('');

  return `
  <section class="hero">
    <div class="big-ring">${ringSvg(p, 108, 9)}</div>
    <div class="hero-body">
      <div class="eyebrow">Low Level Design · Swift</div>
      <h1>${p === 100 ? 'Curriculum complete 🎉' : 'Your learning dashboard'}</h1>
      <p class="sub">${o.done} of ${o.total} tracked items done across ${content.modules.length} modules.
      ${next ? `Next up: <a href="${nextHref}"><b>${esc(next.item.title)}</b></a> in M${esc(next.module.num)}.` : 'Nothing left in the queue.'}</p>
      <div class="hero-actions">
        ${next ? `<a class="btn primary" href="${nextHref}">Continue learning →</a>` : ''}
        <a class="btn" href="#/browse">Browse everything</a>
        <a class="btn" href="#/resources">Reading &amp; videos</a>
        <button class="btn" data-act="add-module">+ New module</button>
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
  <div class="items">${recent.map((r) => {
    const s = content.itemSection.get(r.id);
    return `<a class="item" style="display:block" href="#/m/${r.module.id}/${s ? s.id : ''}/${encodeURIComponent(r.id)}">
      <div class="item-head">
        <span class="tick" style="background:var(--ok);border-color:var(--ok);color:#fff">✓</span>
        <div class="item-main">
          <div class="item-title">${esc(r.item.title)}</div>
          <div class="item-sub"><span class="tag">M${esc(r.module.num)} · ${esc(r.module.title)}</span><span class="muted">${esc(timeAgo(r.at))}</span></div>
        </div>
      </div></a>`;
  }).join('')}
  </div>` : ''}

  ${phases}`;
}

function moduleCard(m) {
  const p = moduleProgress(m);
  const v = pct(p.done, p.total);
  const complete = p.total && p.done === p.total;
  const probs = m.sections.find((s) => s.id === 'problems');
  const links = m.sections.reduce((a, s) => a + sectionLinks(m, s).length, 0);
  return `<a class="card mod-card ${complete ? 'done' : ''}" href="#/m/${m.id}">
    <div class="mc-top">
      <span class="mc-num">M${esc(m.num)}</span>
      <span class="mc-title">${esc(m.title)}</span>
      ${complete ? '<span class="mc-check">✓</span>' : ''}
    </div>
    <div class="mc-meta">
      <span>${m.sections.length} sections</span>
      ${probs ? `<span>${probs.items.length} problems</span>` : ''}
      ${links ? `<span>🔗 ${links}</span>` : ''}
      ${m.difficulty ? `<span class="tag ${m.difficulty}">${m.difficulty}</span>` : ''}
    </div>
    <div class="bar-row">${barHtml(v, complete ? 'ok' : '')}<span class="pct">${p.done}/${p.total} · ${v}%</span></div>
  </a>`;
}

/* ------------------------------------------------------------ module */

function moduleHead(mod, secId) {
  const p = moduleProgress(mod);
  const v = pct(p.done, p.total);
  const phase = allPhases().find((x) => x.id === mod.phaseId);
  const secTitle = secId ? mod.sections.find((s) => s.id === secId)?.title : null;
  return `
  <div class="page-head">
    <div class="crumbs">
      <a href="#/">Dashboard</a> <span>/</span>
      <a href="#/m/${mod.id}">Module ${esc(mod.num)}</a>
      ${secTitle ? `<span>/</span> <span>${esc(secTitle)}</span>` : ''}
    </div>
    <div class="spread">
      <div>
        <div class="eyebrow">${esc(phase ? phase.title : '')}</div>
        <h1>${esc(mod.title)}</h1>
      </div>
      <div class="row">
        ${mod.custom ? `<button class="btn sm" data-act="add-section" data-mod="${esc(mod.id)}">+ Section</button>` : ''}
        <button class="btn sm danger" data-act="reset-module" data-mod="${esc(mod.id)}">Reset module</button>
        ${mod.custom ? `<button class="btn sm danger" data-act="del-module" data-mod="${esc(mod.id)}">Delete module</button>` : ''}
      </div>
    </div>
    <div class="bar-row" style="margin-top:14px">
      ${barHtml(v, v === 100 ? 'ok' : '')}<span class="pct">${p.done}/${p.total} · ${v}%</span>
    </div>
  </div>`;
}

/** Overview: one card per section, with its progress and its links. */
function sectionOverview(mod) {
  const anyFilter = filters.q || filtersActive();
  const cards = mod.sections.map((sec) => {
    const sp = sectionProgress(sec);
    const links = sectionLinks(mod, sec);
    const visible = anyFilter ? sec.items.filter(matches) : sec.items;
    if (anyFilter && !visible.length) return '';
    return `<a class="card sec-card" href="#/m/${mod.id}/${esc(sec.id)}" data-section="${esc(sec.id)}">
      <div class="sc-top">
        <span class="sc-icon">${KIND_META[sec.kind] ? KIND_META[sec.kind].icon : '▤'}</span>
        <span class="sc-title">${esc(sec.title)}</span>
        ${sec.source && sec.source !== 'mine' ? `<span class="src">${esc(sec.source)}</span>` : '<span class="tag accent">mine</span>'}
      </div>
      <div class="sc-meta">
        <span>${visible.length} item${visible.length === 1 ? '' : 's'}</span>
        ${linkCountChips(links)}
      </div>
      <div class="bar-row">
        ${barHtml(sp.total ? pct(sp.done, sp.total) : 0, sp.total && sp.done === sp.total ? 'ok' : '')}
        <span class="pct">${sp.total ? `${sp.done}/${sp.total}` : 'reference'}</span>
      </div>
    </a>`;
  }).join('');

  return `<div class="grid secs">${cards || '<div class="empty-state"><div class="big">🔍</div><p>No section matches the current filters.</p></div>'}</div>
    ${mod.custom ? `<div class="sec-add"><button class="btn sm" data-act="add-section" data-mod="${esc(mod.id)}">+ Add a section</button></div>` : ''}`;
}

/** The vertical, sticky switcher shown while one section is open. */
function sectionRail(mod, activeId) {
  return `<aside class="sec-rail" aria-label="Sections">
    <a class="rail-tab all" href="#/m/${mod.id}">◳ All sections</a>
    ${mod.sections.map((sec) => {
      const sp = sectionProgress(sec);
      const v = pct(sp.done, sp.total);
      return `<a class="rail-tab ${sec.id === activeId ? 'active' : ''}" href="#/m/${mod.id}/${esc(sec.id)}">
        <span class="rt-icon">${KIND_META[sec.kind] ? KIND_META[sec.kind].icon : '▤'}</span>
        <span class="rt-body">
          <span class="rt-title">${esc(sec.title)}</span>
          <span class="rt-meta">${sp.total ? `${sp.done}/${sp.total}` : 'ref'}</span>
          <span class="rt-bar"><i style="width:${v}%"></i></span>
        </span>
      </a>`;
    }).join('')}
  </aside>`;
}

function sectionBody(mod, sec, focusItemId) {
  const anyFilter = filters.q || filtersActive();
  const visible = anyFilter ? sec.items.filter(matches) : sec.items;
  const sp = sectionProgress(sec);
  const groups = groupItems(visible);

  const inner = [...groups.entries()].map(([g, items]) => `
    <div class="group-wrap">
      ${g ? `<div class="group-label">${esc(g)} <span class="muted">· ${items.length}</span></div>` : ''}
      <div class="items">${items.map((it) => itemCard(it, { open: it.id === focusItemId })).join('')}</div>
    </div>`).join('');

  return `<section class="sec-block open-section" data-section="${esc(sec.id)}">
    <div class="sec-bar" aria-expanded="true">
      <h3>${esc(sec.title)}</h3>
      ${sec.source && sec.source !== 'mine' ? `<span class="src">${esc(sec.source)}</span>` : '<span class="tag accent">mine</span>'}
      ${linkCountChips(sectionLinks(mod, sec))}
      <span class="spacer"></span>
      ${sp.total ? `<span class="mini">${barHtml(pct(sp.done, sp.total), sp.done === sp.total ? 'ok' : 'thin')}</span>
        <span class="muted">${sp.done}/${sp.total}</span>` : '<span class="muted">reference</span>'}
    </div>
    <div class="sec-content">
      ${sectionLinkPanel(mod, sec)}
      ${inner || '<p class="empty-note">Nothing here yet.</p>'}
      <div class="sec-add">
        <button class="btn sm" data-act="add-topic" data-mod="${esc(mod.id)}" data-sec="${esc(sec.id)}">+ Add topic</button>
        ${sec.custom ? `<button class="btn sm danger" data-act="del-section" data-sec="${esc(sec.id)}">Delete section</button>` : ''}
      </div>
    </div>
  </section>`;
}

export function viewModule(mod, secId = null, focusItemId = null) {
  const sec = secId ? mod.sections.find((s) => s.id === secId) : null;
  if (!sec) {
    return `${moduleHead(mod, null)}
      ${filters.q || filtersActive() ? '<p class="muted">Filters are on — sections show only matching items.</p>' : ''}
      ${sectionOverview(mod)}`;
  }
  return `${moduleHead(mod, secId)}
    <div class="mod-layout">
      <div class="mod-main">${sectionBody(mod, sec, focusItemId)}</div>
      ${sectionRail(mod, secId)}
    </div>`;
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
  const hit = (s) => !q || String(s).toLowerCase().includes(q);

  const blocks = content.modules.map((m) => {
    const secRows = m.sections.map((sec) => {
      const links = sectionLinks(m, sec)
        .filter(({ r, item }) => hit(`${r.label || r.title} ${r.url} ${item ? item.title : ''} ${sec.title} ${m.title}`));
      if (!links.length) return '';
      const bucket = sectionBucket(m.id, sec.id);
      return `<div class="res-sec">
        <div class="res-sec-head">
          <a href="#/m/${m.id}/${esc(sec.id)}">${esc(sec.title)}</a>
          <span class="muted">${links.length}</span>
          <span class="spacer"></span>
          <button class="btn sm" data-act="add-section-res" data-bucket="${esc(bucket)}">+ Add</button>
        </div>
        <div class="res-list">${links.map(({ r, item }) => ownedLinkRow(
          r,
          item ? item.id : bucket,
          item
            ? `<span class="res-owner" data-act="goto-item" data-target="${esc(item.id)}" role="button" tabindex="0">${esc(item.title)}</span>`
            : '<span class="res-owner muted">whole section</span>',
        )).join('')}</div>
      </div>`;
    }).join('');
    if (!secRows) return '';
    const count = m.sections.reduce((a, s) => a + sectionLinks(m, s).length, 0);
    return `<section class="card res-mod">
      <div class="res-mod-head">
        <span class="mc-num">M${esc(m.num)}</span>
        <a href="#/m/${m.id}"><b>${esc(m.title)}</b></a>
        <span class="muted">${count} link${count === 1 ? '' : 's'}</span>
      </div>
      ${secRows}
    </section>`;
  }).join('');

  const globals = globalResources().filter((r) => hit(`${r.title || r.label} ${r.url}`));
  const total = content.modules.reduce((a, m) => a + m.sections.reduce((b, s) => b + sectionLinks(m, s).length, 0), 0) + globals.length;

  return `
  <div class="page-head">
    <div class="eyebrow">Library</div>
    <h1>Reading &amp; videos <span class="muted">· ${total} links</span></h1>
    <p class="sub">Seeded from the <a href="https://krucible.netlify.app/" target="_blank" rel="noopener noreferrer">Krucible LLD sheet</a>
    and filed under the module and section each link belongs to — the same links show up on those sections in place.
    Add your own to a section, an item, or to the general list.</p>
  </div>

  <section class="card res-mod">
    <div class="res-mod-head">
      <span class="mc-num">GEN</span><b>General resources</b>
      <span class="muted">${globals.length}</span>
      <span class="spacer"></span>
      <button class="btn sm" data-act="add-global-res">+ Add</button>
    </div>
    <div class="res-list">
      ${globals.map((r) => `<div class="res">
        <span class="rtype">${RES_ICON[r.type] || '🔗'}</span>
        <a class="rlabel" href="${esc(safeUrl(r.url) || '#')}" target="_blank" rel="noopener noreferrer">${esc(r.title || r.label)}</a>
        <span class="rurl">${esc((safeUrl(r.url) || '').replace(/^https?:\/\//, ''))}</span>
        <span class="ract">
          <button class="ibtn" data-act="edit-global-res" data-res="${esc(r.id)}" title="Edit">✎</button>
          <button class="ibtn" data-act="del-global-res" data-res="${esc(r.id)}" title="Remove">✕</button>
        </span></div>`).join('') || '<p class="empty-note">No general links.</p>'}
    </div>
  </section>

  ${blocks || '<p class="empty-note" style="margin-top:14px">No links match that search.</p>'}`;
}

/* ---------------------------------------------------------- settings */
export function viewSettings() {
  const o = overallProgress();
  const connected = !!gh.token;
  const c = state.custom;
  return `
  <div class="page-head">
    <div class="eyebrow">Settings</div>
    <h1>Settings &amp; sync</h1>
  </div>

  <section class="card" style="padding:18px;margin-bottom:16px">
    <div class="spread"><h2 class="sec" style="margin:0">Cross-browser sync (GitHub Gist)</h2>
      <span class="tag ${connected ? 'accent' : ''}">${connected ? `connected as @${esc(gh.user ? gh.user.login : '')}` : 'not connected'}</span></div>
    <p class="sub" style="margin-top:8px">Your token is your account. A different token means a different private Gist — and therefore a separate set of progress, notes, tags, links and custom modules.</p>

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
    <h2 class="sec" style="margin:0 0 10px">Your own content</h2>
    <p class="sub">${c.modules.length} module${c.modules.length === 1 ? '' : 's'},
      ${c.sections.length} section${c.sections.length === 1 ? '' : 's'} and
      ${c.items.length} topic${c.items.length === 1 ? '' : 's'} added by you. They sync with everything else.</p>
    <div class="row" style="margin-top:10px"><button class="btn" data-act="add-module">+ New module</button></div>
  </section>

  <section class="card" style="padding:18px;margin-bottom:16px">
    <h2 class="sec" style="margin:0 0 10px">Backup</h2>
    <p class="sub">A plain JSON file with every tick, note, tag, link and custom module — independent of GitHub.</p>
    <div class="row" style="margin-top:10px">
      <button class="btn" data-act="export">Export JSON</button>
      <button class="btn" data-act="import">Import JSON</button>
    </div>
  </section>

  <section class="card" style="padding:18px">
    <h2 class="sec" style="margin:0 0 10px">Danger zone</h2>
    <p class="sub">“Reset progress” clears completion only — <b>notes, tags, favourites, links and your modules are kept</b>. “Erase everything” removes all of it.</p>
    <div class="row" style="margin-top:12px">
      <button class="btn danger" data-act="reset-all">Reset all progress (${o.done} ticks)</button>
      <button class="btn danger" data-act="erase-all">Erase everything</button>
    </div>
  </section>

  <p class="muted" style="margin-top:22px">
    ${content.data.stats.items} generated items · ${content.data.stats.seededLinks} seeded links ·
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
  $('#sideModules').innerHTML = `${content.modules.map((m) => {
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
  }).join('')}
  <button class="side-mod add-mod" data-act="add-module">
    <div class="sm-top"><span class="sm-num">+</span><span class="sm-title">New module</span></div>
  </button>`;
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
