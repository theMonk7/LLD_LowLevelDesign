/* Content index + user state (progress, notes, tags, favourites, resources).
   State lives in localStorage and, when a GitHub token is connected, in a
   private Gist so it follows you across browsers. */

import { debounce } from './util.js';

const LS_STATE = 'lld.state.v1';
const LS_PREFS = 'lld.prefs.v1';

export const DEFAULT_PREFS = {
  theme: 'indigo',
  mode: 'dark',
  collapsed: {},     // sectionKey -> true when collapsed
  revealSolutions: false,
};

export const content = {
  loaded: false,
  data: null,
  modules: [],
  moduleById: new Map(),
  itemById: new Map(),
  itemModule: new Map(),
  itemSection: new Map(),
  allItems: [],
  builtinTags: [],
  bodies: new Map(),   // moduleId -> { itemId: markdown }
};

export const state = {
  v: 1,
  updatedAt: 0,
  items: {},          // itemId -> { done, doneAt, fav, notes, tags[], res:{add[],hide[],edit{}} }
  prefs: { ...DEFAULT_PREFS },
  extraResources: [], // user-added global resources
  hiddenExtras: [],
  // Everything the user adds on top of the generated curriculum.
  custom: { modules: [], sections: [], items: [] },
};

const emptyCustom = () => ({ modules: [], sections: [], items: [] });
const normCustom = (c) => ({
  modules: Array.isArray(c?.modules) ? c.modules : [],
  sections: Array.isArray(c?.sections) ? c.sections : [],
  items: Array.isArray(c?.items) ? c.items : [],
});
export const newId = (p) => `${p}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 6)}`;

/* ----------------------------------------------------------- events */
const listeners = new Set();
export const subscribe = (fn) => { listeners.add(fn); return () => listeners.delete(fn); };
let silent = 0;
export function emit(detail = {}) { if (!silent) listeners.forEach((f) => f(detail)); }
export function batch(fn) { silent += 1; try { fn(); } finally { silent -= 1; } emit({ bulk: true }); }

/* ------------------------------------------------------ persistence */
let remotePush = null;   // set by gist.js
export function setRemotePush(fn) { remotePush = fn; }

const savePrefsSoon = debounce(() => {
  localStorage.setItem(LS_PREFS, JSON.stringify(state.prefs));
}, 150);

const pushSoon = debounce(() => { if (remotePush) remotePush(); }, 1800);

export function persist({ remote = true } = {}) {
  state.updatedAt = Date.now();
  try {
    localStorage.setItem(LS_STATE, JSON.stringify({
      v: state.v, updatedAt: state.updatedAt, items: state.items,
      extraResources: state.extraResources, hiddenExtras: state.hiddenExtras,
      custom: state.custom,
    }));
  } catch (e) {
    console.warn('localStorage write failed', e);
  }
  savePrefsSoon();
  if (remote) pushSoon();
}

export function flushRemote() { pushSoon.flush(); }

export function loadLocal() {
  try {
    const raw = JSON.parse(localStorage.getItem(LS_STATE) || 'null');
    if (raw && raw.items) {
      state.items = raw.items;
      state.updatedAt = raw.updatedAt || 0;
      state.extraResources = raw.extraResources || [];
      state.hiddenExtras = raw.hiddenExtras || [];
      state.custom = normCustom(raw.custom);
    }
  } catch { /* corrupt payload — start clean */ }
  try {
    const p = JSON.parse(localStorage.getItem(LS_PREFS) || 'null');
    if (p) state.prefs = { ...DEFAULT_PREFS, ...p };
  } catch { /* ignore */ }
}

/** Replace the whole user state (used after a Gist pull). */
export function hydrate(remote) {
  if (!remote || typeof remote !== 'object') return;
  state.items = remote.items || {};
  state.updatedAt = remote.updatedAt || Date.now();
  state.extraResources = remote.extraResources || [];
  state.hiddenExtras = remote.hiddenExtras || [];
  state.custom = normCustom(remote.custom);
  if (remote.prefs) state.prefs = { ...DEFAULT_PREFS, ...remote.prefs };
  if (content.loaded) rebuildIndex();
  localStorage.setItem(LS_STATE, JSON.stringify({
    v: 1, updatedAt: state.updatedAt, items: state.items,
    extraResources: state.extraResources, hiddenExtras: state.hiddenExtras,
    custom: state.custom,
  }));
  localStorage.setItem(LS_PREFS, JSON.stringify(state.prefs));
  emit({ bulk: true });
}

export function exportState() {
  return {
    v: 1,
    updatedAt: state.updatedAt || Date.now(),
    items: state.items,
    prefs: state.prefs,
    extraResources: state.extraResources,
    hiddenExtras: state.hiddenExtras,
    custom: state.custom,
  };
}

/* --------------------------------------------------------- content */
export async function loadContent() {
  const res = await fetch('data/content.json', { cache: 'no-cache' });
  if (!res.ok) throw new Error(`content.json ${res.status}`);
  content.data = await res.json();
  content.loaded = true;
  rebuildIndex();
  return content.data;
}

export const CUSTOM_PHASE = 'pcustom';

/** Fold the user's own modules, sections and topics into the generated set. */
export function rebuildIndex() {
  const base = content.data;
  const mods = base.modules.map((m) => ({
    ...m,
    sections: m.sections.map((sec) => ({ ...sec, items: [...sec.items] })),
  }));
  const byId = new Map(mods.map((m) => [m.id, m]));

  for (const cm of state.custom.modules) {
    const m = { ...cm, custom: true, phaseId: CUSTOM_PHASE, sections: [] };
    mods.push(m);
    byId.set(m.id, m);
  }
  for (const cs of state.custom.sections) {
    const m = byId.get(cs.moduleId);
    if (m) m.sections.push({ ...cs, custom: true, items: [] });
  }
  for (const ci of state.custom.items) {
    const m = byId.get(ci.moduleId);
    const sec = m?.sections.find((x) => x.id === ci.sectionId);
    if (sec) sec.items.push({ ...ci, custom: true, trackable: true, resources: ci.resources || [] });
  }

  content.modules = mods;
  content.moduleById = new Map();
  content.itemById = new Map();
  content.itemModule = new Map();
  content.itemSection = new Map();
  content.allItems = [];

  const tags = new Set();
  for (const m of mods) {
    content.moduleById.set(m.id, m);
    m.totals = {
      items: m.sections.reduce((a, x) => a + x.items.length, 0),
      trackable: m.sections.reduce((a, x) => a + x.items.filter((i) => i.trackable).length, 0),
    };
    for (const sec of m.sections) {
      for (const it of sec.items) {
        content.itemById.set(it.id, it);
        content.itemModule.set(it.id, m);
        content.itemSection.set(it.id, sec);
        content.allItems.push(it);
        (it.tags || []).forEach((t) => tags.add(t));
      }
    }
  }
  content.builtinTags = [...tags].sort((a, b) => a.localeCompare(b));
}

/* --------------------------------------------- user modules and topics */
export function addCustomModule({ title, difficulty = null }) {
  const n = state.custom.modules.length + 1;
  const m = { id: newId('cm'), num: `U${n}`, title: title.trim() || `My module ${n}`, difficulty };
  state.custom.modules.push(m);
  state.custom.sections.push({ id: newId('cs'), moduleId: m.id, title: 'Topics', kind: 'concept', source: 'mine' });
  rebuildIndex(); persist(); emit({ bulk: true });
  return m;
}

export function addCustomSection({ moduleId, title, kind = 'concept' }) {
  const sec = { id: newId('cs'), moduleId, title: title.trim() || 'New section', kind, source: 'mine' };
  state.custom.sections.push(sec);
  rebuildIndex(); persist(); emit({ bulk: true });
  return sec;
}

export function addCustomItem({ moduleId, sectionId, title, body = '', kind = 'concept', group = null }) {
  const it = {
    id: newId('ci'), moduleId, sectionId, title: title.trim() || 'New topic',
    body, kind, group, difficulty: null, tags: [], resources: [],
  };
  state.custom.items.push(it);
  rebuildIndex(); persist(); emit({ bulk: true });
  return it;
}

export function updateCustom(kind, id, patch) {
  const list = state.custom[kind];
  const row = list.find((x) => x.id === id);
  if (!row) return;
  Object.assign(row, patch);
  rebuildIndex(); persist(); emit({ bulk: true });
}

/** Remove a user-made module, section or topic, plus everything under it. */
export function removeCustom(kind, id) {
  if (kind === 'modules') {
    state.custom.modules = state.custom.modules.filter((x) => x.id !== id);
    state.custom.sections = state.custom.sections.filter((x) => x.moduleId !== id);
    state.custom.items = state.custom.items.filter((x) => x.moduleId !== id);
  } else if (kind === 'sections') {
    state.custom.sections = state.custom.sections.filter((x) => x.id !== id);
    state.custom.items = state.custom.items.filter((x) => x.sectionId !== id);
  } else {
    state.custom.items = state.custom.items.filter((x) => x.id !== id);
    delete state.items[id];
  }
  rebuildIndex(); persist(); emit({ bulk: true });
}

export const isCustomItem = (id) => state.custom.items.some((x) => x.id === id);

export async function loadBodies(moduleId) {
  if (moduleId.startsWith('cm-')) return {};
  if (content.bodies.has(moduleId)) return content.bodies.get(moduleId);
  const res = await fetch(`data/modules/${moduleId}.json`, { cache: 'no-cache' });
  if (!res.ok) throw new Error(`${moduleId}.json ${res.status}`);
  const json = await res.json();
  content.bodies.set(moduleId, json.bodies);
  return json.bodies;
}

export function bodyOf(itemId) {
  const own = state.custom.items.find((x) => x.id === itemId);
  if (own) return own.body || '';
  const m = content.itemModule.get(itemId);
  if (!m) return null;
  const b = content.bodies.get(m.id);
  return b ? b[itemId] ?? null : null;
}

/* --------------------------------------------------- state accessors */
export function entry(id, create = false) {
  let e = state.items[id];
  if (!e && create) {
    e = { done: false, doneAt: 0, fav: false, notes: '', tags: [], res: { add: [], hide: [], edit: {} } };
    state.items[id] = e;
  }
  if (e && !e.res) e.res = { add: [], hide: [], edit: {} };
  return e;
}

export const isDone = (id) => !!state.items[id]?.done;
export const isFav = (id) => !!state.items[id]?.fav;
export const notesOf = (id) => state.items[id]?.notes || '';
export const userTags = (id) => state.items[id]?.tags || [];
export const tagsOf = (id) => [...(content.itemById.get(id)?.tags || []), ...userTags(id)];

export function setDone(id, done) {
  const e = entry(id, true);
  e.done = done;
  e.doneAt = done ? Date.now() : 0;
  persist();
  emit({ item: id });
}
export const toggleDone = (id) => setDone(id, !isDone(id));

export function toggleFav(id) {
  const e = entry(id, true);
  e.fav = !e.fav;
  persist();
  emit({ item: id });
}

export function setNotes(id, text) {
  const e = entry(id, true);
  e.notes = text;
  persist();
  emit({ item: id, quiet: true });
}

export function addTag(id, tag) {
  const t = String(tag).trim().slice(0, 32);
  if (!t) return;
  const e = entry(id, true);
  const existing = tagsOf(id).map((x) => x.toLowerCase());
  if (existing.includes(t.toLowerCase())) return;
  e.tags.push(t);
  persist();
  emit({ item: id });
}

export function removeTag(id, tag) {
  const e = entry(id, true);
  const item = content.itemById.get(id);
  if (e.tags.includes(tag)) e.tags = e.tags.filter((t) => t !== tag);
  else if (item && item.tags.includes(tag)) {
    // hide a generated tag by recording a removal marker
    e.hiddenTags = [...(e.hiddenTags || []), tag];
  }
  persist();
  emit({ item: id });
}

export function renameTag(id, from, to) {
  removeTag(id, from);
  addTag(id, to);
}

export const hiddenTags = (id) => state.items[id]?.hiddenTags || [];

export function visibleTags(id) {
  const hid = hiddenTags(id);
  const item = content.itemById.get(id);
  return [
    ...(item ? item.tags.filter((t) => !hid.includes(t)).map((t) => ({ t, seed: true })) : []),
    ...userTags(id).map((t) => ({ t, seed: false })),
  ];
}

/* ------------------------------------------------------- resources */
export function resourcesOf(id) {
  const item = content.itemById.get(id);
  const e = state.items[id];
  const hide = e?.res?.hide || [];
  const edit = e?.res?.edit || {};
  const seeds = (item?.resources || [])
    .filter((r) => !hide.includes(r.id))
    .map((r) => ({ ...r, ...(edit[r.id] || {}) }));
  return [...seeds, ...(e?.res?.add || [])];
}

export function addResource(id, { type, label, url }) {
  const e = entry(id, true);
  e.res.add.push({ id: `u${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`, type, label, url, seed: false });
  persist();
  emit({ item: id });
}

export function updateResource(id, resId, patch) {
  const e = entry(id, true);
  const custom = e.res.add.find((r) => r.id === resId);
  if (custom) Object.assign(custom, patch);
  else e.res.edit[resId] = { ...(e.res.edit[resId] || {}), ...patch };
  persist();
  emit({ item: id });
}

export function removeResource(id, resId) {
  const e = entry(id, true);
  if (e.res.add.some((r) => r.id === resId)) e.res.add = e.res.add.filter((r) => r.id !== resId);
  else if (!e.res.hide.includes(resId)) e.res.hide.push(resId);
  persist();
  emit({ item: id });
}

/* global (non-item) resources */
export function globalResources() {
  const seeds = (content.data?.extraResources || []).filter((r) => !state.hiddenExtras.includes(r.id));
  return [...seeds, ...state.extraResources];
}
export function addGlobalResource(r) {
  state.extraResources.push({ id: `g${Date.now().toString(36)}`, seed: false, ...r });
  persist(); emit({});
}
export function updateGlobalResource(rid, patch) {
  const own = state.extraResources.find((r) => r.id === rid);
  if (own) { Object.assign(own, patch); persist(); emit({}); return; }
  const seed = (content.data?.extraResources || []).find((r) => r.id === rid);
  if (seed) {
    if (!state.hiddenExtras.includes(rid)) state.hiddenExtras.push(rid);
    state.extraResources.push({ ...seed, ...patch, id: `g${Date.now().toString(36)}`, seed: false });
    persist(); emit({});
  }
}
export function removeGlobalResource(rid) {
  if (state.extraResources.some((r) => r.id === rid)) state.extraResources = state.extraResources.filter((r) => r.id !== rid);
  else if (!state.hiddenExtras.includes(rid)) state.hiddenExtras.push(rid);
  persist(); emit({});
}

/* -------------------------------------------------------- progress */
export function sectionProgress(section) {
  const track = section.items.filter((i) => i.trackable);
  return { done: track.filter((i) => isDone(i.id)).length, total: track.length };
}

export function moduleProgress(mod) {
  let done = 0, total = 0;
  for (const s of mod.sections) {
    const p = sectionProgress(s);
    done += p.done; total += p.total;
  }
  return { done, total };
}

export function overallProgress() {
  let done = 0, total = 0;
  for (const m of content.modules) {
    const p = moduleProgress(m);
    done += p.done; total += p.total;
  }
  return { done, total };
}

export function phaseProgress(phaseId) {
  let done = 0, total = 0;
  for (const m of content.modules.filter((x) => x.phaseId === phaseId)) {
    const p = moduleProgress(m);
    done += p.done; total += p.total;
  }
  return { done, total };
}

export function countsByKind() {
  const out = {};
  for (const it of content.allItems) {
    if (!it.trackable) continue;
    out[it.kind] = out[it.kind] || { done: 0, total: 0 };
    out[it.kind].total += 1;
    if (isDone(it.id)) out[it.kind].done += 1;
  }
  return out;
}

export function recentlyDone(n = 8) {
  return Object.entries(state.items)
    .filter(([, e]) => e.done && e.doneAt)
    .sort((a, b) => b[1].doneAt - a[1].doneAt)
    .slice(0, n)
    .map(([id, e]) => ({ id, at: e.doneAt, item: content.itemById.get(id), module: content.itemModule.get(id) }))
    .filter((x) => x.item);
}

export function favourites() {
  return Object.entries(state.items)
    .filter(([, e]) => e.fav)
    .map(([id]) => ({ id, item: content.itemById.get(id), module: content.itemModule.get(id) }))
    .filter((x) => x.item);
}

export function withNotes() {
  return Object.entries(state.items)
    .filter(([, e]) => (e.notes || '').trim())
    .map(([id]) => ({ id, item: content.itemById.get(id), module: content.itemModule.get(id) }))
    .filter((x) => x.item);
}

/** First not-done trackable item, in curriculum order. */
export function nextUp() {
  for (const m of content.modules) {
    for (const s of m.sections) {
      for (const it of s.items) {
        if (it.trackable && !isDone(it.id)) return { item: it, module: m, section: s };
      }
    }
  }
  return null;
}

/* ----------------------------------------------------------- resets */
/** Clears completion only. Notes, tags, favourites and links are kept. */
export function resetProgress(moduleId = null) {
  const ids = moduleId
    ? (content.moduleById.get(moduleId)?.sections.flatMap((s) => s.items.map((i) => i.id)) || [])
    : Object.keys(state.items);
  for (const id of ids) {
    const e = state.items[id];
    if (e) { e.done = false; e.doneAt = 0; }
  }
  persist();
  emit({ bulk: true });
}

/** Nuclear: progress + notes + tags + favourites + custom links for a scope. */
export function resetEverything(moduleId = null) {
  if (!moduleId) {
    state.items = {};
    state.extraResources = [];
    state.hiddenExtras = [];
    state.custom = emptyCustom();
    rebuildIndex();
  } else {
    const mod = content.moduleById.get(moduleId);
    for (const s of mod.sections) for (const i of s.items) delete state.items[i.id];
  }
  persist();
  emit({ bulk: true });
}

/* ----------------------------------------------------------- prefs */
export function setPref(key, value) {
  state.prefs[key] = value;
  savePrefsSoon();
  pushSoon();
}

export function applyTheme() {
  document.documentElement.dataset.theme = state.prefs.theme || 'indigo';
  document.documentElement.dataset.mode = state.prefs.mode || 'dark';
}
