/* GitHub Gist backend.

   The GitHub token *is* the account: a different token sees a different Gist
   and therefore a different set of progress, notes and links. The token is
   stored in this browser's localStorage and sent only to api.github.com. */

import { exportState, hydrate, setRemotePush, state } from './store.js';
import { toast } from './util.js';

const API = 'https://api.github.com';
const FILE = 'lld-dashboard-state.json';
const DESC = 'LLD Mastery dashboard — personal progress state';
const LS_TOKEN = 'lld.gh.token';
const LS_GIST = 'lld.gh.gist';

export const gh = {
  token: null,
  user: null,
  gistId: null,
  status: 'local',      // local | syncing | synced | error
  message: 'Local only — progress stays in this browser',
  lastSync: 0,
};

const watchers = new Set();
export const onSync = (fn) => { watchers.add(fn); return () => watchers.delete(fn); };
function setStatus(status, message) {
  gh.status = status;
  gh.message = message;
  watchers.forEach((f) => f(gh));
}

async function api(path, opts = {}) {
  const res = await fetch(API + path, {
    ...opts,
    headers: {
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      Authorization: `Bearer ${gh.token}`,
      ...(opts.body ? { 'Content-Type': 'application/json' } : {}),
      ...opts.headers,
    },
  });
  if (!res.ok) {
    let detail = '';
    try { detail = (await res.json()).message || ''; } catch { /* no body */ }
    const err = new Error(`GitHub ${res.status}${detail ? `: ${detail}` : ''}`);
    err.status = res.status;
    throw err;
  }
  return res.status === 204 ? null : res.json();
}

/* --------------------------------------------------------- discovery */
async function findGist() {
  for (let page = 1; page <= 3; page += 1) {
    const list = await api(`/gists?per_page=100&page=${page}`);
    const hit = list.find((g) => g.files && g.files[FILE]);
    if (hit) return hit.id;
    if (list.length < 100) break;
  }
  return null;
}

async function createGist() {
  const g = await api('/gists', {
    method: 'POST',
    body: JSON.stringify({
      description: DESC,
      public: false,
      files: { [FILE]: { content: JSON.stringify(exportState(), null, 2) } },
    }),
  });
  return g.id;
}

async function readGist(id) {
  const g = await api(`/gists/${id}`);
  const f = g.files?.[FILE];
  if (!f) return null;
  // Gists over 1 MB come back truncated with a raw_url to fetch instead.
  const text = f.truncated ? await (await fetch(f.raw_url)).text() : f.content;
  try { return JSON.parse(text); } catch { return null; }
}

/* -------------------------------------------------------------- push */
let pushing = false;
let pushQueued = false;

async function push() {
  if (!gh.token || !gh.gistId) return;
  if (pushing) { pushQueued = true; return; }
  pushing = true;
  setStatus('syncing', 'Saving to Gist…');
  try {
    await api(`/gists/${gh.gistId}`, {
      method: 'PATCH',
      body: JSON.stringify({ files: { [FILE]: { content: JSON.stringify(exportState(), null, 2) } } }),
    });
    gh.lastSync = Date.now();
    setStatus('synced', `Synced as @${gh.user?.login} · just now`);
  } catch (e) {
    setStatus('error', e.message);
    toast(`Sync failed — ${e.message}`, 'err');
  } finally {
    pushing = false;
    if (pushQueued) { pushQueued = false; push(); }
  }
}
setRemotePush(push);
export { push as pushNow };

/* ----------------------------------------------------------- connect */
export async function connect(token, { gistId = null, prefer = 'auto' } = {}) {
  gh.token = token.trim();
  setStatus('syncing', 'Checking token…');
  try {
    gh.user = await api('/user');
  } catch (e) {
    gh.token = null;
    setStatus('error', e.status === 401 ? 'Token rejected by GitHub (401)' : e.message);
    throw e;
  }

  setStatus('syncing', 'Locating your Gist…');
  gh.gistId = gistId || localStorage.getItem(LS_GIST) || (await findGist());
  let remote = null;
  if (gh.gistId) {
    try { remote = await readGist(gh.gistId); }
    catch { gh.gistId = null; }
  }
  if (!gh.gistId) {
    gh.gistId = await createGist();
    remote = null;
  }

  localStorage.setItem(LS_TOKEN, gh.token);
  localStorage.setItem(LS_GIST, gh.gistId);

  const localAt = state.updatedAt || 0;
  const remoteAt = remote?.updatedAt || 0;
  const takeRemote = prefer === 'remote' || (prefer === 'auto' && remote && remoteAt >= localAt);

  if (takeRemote && remote) {
    hydrate(remote);
    gh.lastSync = Date.now();
    setStatus('synced', `Synced as @${gh.user.login} · pulled from Gist`);
    toast('Loaded your saved progress from GitHub', 'ok');
  } else {
    await push();
    toast(remote ? 'Pushed this browser\'s progress to GitHub' : 'Created a private Gist for your progress', 'ok');
  }
  return gh;
}

export async function pull() {
  if (!gh.token || !gh.gistId) return;
  setStatus('syncing', 'Pulling from Gist…');
  try {
    const remote = await readGist(gh.gistId);
    if (remote) { hydrate(remote); toast('Pulled latest from GitHub', 'ok'); }
    gh.lastSync = Date.now();
    setStatus('synced', `Synced as @${gh.user?.login} · just now`);
  } catch (e) {
    setStatus('error', e.message);
  }
}

export function disconnect({ forget = true } = {}) {
  gh.token = null; gh.user = null;
  if (forget) { localStorage.removeItem(LS_TOKEN); localStorage.removeItem(LS_GIST); gh.gistId = null; }
  setStatus('local', 'Local only — progress stays in this browser');
}

/** Restore a previous session's token on page load. */
export async function restore() {
  const token = localStorage.getItem(LS_TOKEN);
  if (!token) return false;
  try {
    await connect(token, { gistId: localStorage.getItem(LS_GIST), prefer: 'remote' });
    return true;
  } catch {
    setStatus('error', 'Saved token no longer works — reconnect in Settings');
    return false;
  }
}
