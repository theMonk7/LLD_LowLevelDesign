/* GitHub Gist backend.

   The GitHub token *is* the account: a different token sees a different Gist
   and therefore a different set of progress, notes and links. The token is
   stored in this browser's localStorage and sent only to api.github.com. */

import { exportState, hydrate, setRemotePush, state } from './store.js?v=10';
import { toast } from './util.js?v=10';
import {
  getSessionToken, setSessionToken, clearSessionToken,
  hasVault, saveVault, openVault, clearVault, purgeLegacyToken, cryptoAvailable,
} from './vault.js?v=10';

const API = 'https://api.github.com';
const FILE = 'lld-dashboard-state.json';
const DESC = 'LLD Mastery dashboard — personal progress state';
const LS_GIST = 'lld.gh.gist';     // suffixed with the account login

export const gh = {
  token: null,
  user: null,
  gistId: null,
  status: 'local',      // local | locked | syncing | synced | error
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

/* One remembered Gist per GitHub account, so two accounts used in the same
   browser never inherit each other's Gist id. */
const gistKey = () => `${LS_GIST}:${gh.user?.login || '_'}`;

const ls = {
  get(k) { try { return localStorage.getItem(k); } catch { return null; } },
  set(k, v) { try { localStorage.setItem(k, v); } catch { /* blocked storage */ } },
  del(k) { try { localStorage.removeItem(k); } catch { /* blocked storage */ } },
};

/* ------------------------------------------------------------- errors */
class GhError extends Error {
  constructor(code, status) { super(code); this.code = code; this.status = status; }
}

export function errorText(e) {
  switch (e?.code) {
    case 'bad_token': return 'GitHub rejected that token. Check it has the gist scope and has not expired.';
    case 'forbidden': return 'That token is not allowed to write this Gist. A fine-grained token needs Gists → Read and write.';
    case 'rate_limited': return 'GitHub is rate-limiting this token. Try again shortly.';
    case 'not_found': return 'That Gist no longer exists.';
    case 'offline': return 'Could not reach api.github.com.';
    default: return `GitHub error${e?.code ? ` (${e.code})` : ''}.`;
  }
}

async function api(path, opts = {}) {
  let res;
  try {
    res = await fetch(API + path, {
      ...opts,
      headers: {
        Accept: 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        ...(gh.token ? { Authorization: `Bearer ${gh.token}` } : {}),
        ...(opts.body ? { 'Content-Type': 'application/json' } : {}),
        ...opts.headers,
      },
    });
  } catch {
    throw new GhError('offline');
  }
  if (res.status === 401) throw new GhError('bad_token', 401);
  if (res.status === 403 || res.status === 429) throw new GhError('rate_limited', res.status);
  if (res.status === 404) throw new GhError('not_found', 404);
  if (!res.ok) throw new GhError(`http_${res.status}`, res.status);
  return res.status === 204 ? null : res.json();
}

/* ---------------------------------------------------------- the Gist */
function filesPayload() {
  return { [FILE]: { content: JSON.stringify(exportState(), null, 2) } };
}

function parseGistFile(file) {
  if (!file) return null;
  const text = file.content;
  try { return JSON.parse(text); } catch { return null; }
}

async function readGistBody(g) {
  const f = g.files?.[FILE];
  if (!f) return null;
  // Gists over 1 MB come back truncated with a raw_url to fetch instead.
  if (f.truncated && f.raw_url) {
    try { return JSON.parse(await (await fetch(f.raw_url)).text()); } catch { return null; }
  }
  return parseGistFile(f);
}

/** Resolve the account's Gist: stored id (ownership-checked) → search → create. */
async function findOrCreateGist(candidateId, allowRetry = true) {
  if (candidateId) {
    try {
      const g = await api(`/gists/${candidateId}`);
      // A secret Gist is readable by anyone holding its id, so a stored id is not
      // proof of ownership. Without this check a second account in this browser
      // could read the first one's Gist and then fail every write to it.
      if (g?.owner?.login && gh.user && g.owner.login === gh.user.login) {
        gh.gistId = g.id;
        return g;
      }
    } catch (e) {
      if (e.code !== 'not_found' || !allowRetry) throw e;
    }
  }

  for (let page = 1; page <= 3; page += 1) {
    const list = await api(`/gists?per_page=100&page=${page}`);
    const hit = list.find((g) => g.owner?.login === gh.user.login && g.files?.[FILE]);
    if (hit) { gh.gistId = hit.id; return api(`/gists/${hit.id}`); }
    if (list.length < 100) break;
  }

  const created = await api('/gists', {
    method: 'POST',
    body: JSON.stringify({ description: DESC, public: false, files: filesPayload() }),
  });
  gh.gistId = created.id;
  return created;
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
    await api(`/gists/${gh.gistId}`, { method: 'PATCH', body: JSON.stringify({ files: filesPayload() }) });
    gh.lastSync = Date.now();
    setStatus('synced', `Synced as @${gh.user?.login} · just now`);
  } catch (e) {
    setStatus('error', errorText(e));
    toast(`Sync failed — ${errorText(e)}`, 'err');
  } finally {
    pushing = false;
    if (pushQueued) { pushQueued = false; push(); }
  }
}
setRemotePush(push);
export { push as pushNow };

/* ----------------------------------------------------------- connect */
export async function connect(token, { gistId = null, prefer = 'auto', remember = null } = {}) {
  gh.token = String(token || '').trim();
  if (!gh.token) throw new GhError('bad_token');

  setStatus('syncing', 'Checking token…');
  try {
    const u = await api('/user');
    gh.user = { login: u.login, name: u.name || u.login, avatar: u.avatar_url };
  } catch (e) {
    gh.token = null;
    setStatus('error', errorText(e));
    throw e;
  }

  setStatus('syncing', 'Locating your Gist…');
  let g;
  try {
    g = await findOrCreateGist(gistId || ls.get(gistKey()));
  } catch (e) {
    gh.token = null; gh.user = null;
    setStatus('error', errorText(e));
    throw e;
  }

  ls.set(gistKey(), gh.gistId);
  setSessionToken(gh.token);
  if (remember) {
    try { await saveVault(gh.token, remember); }
    catch (err) { toast(`Not remembered — ${err.message}`, 'err'); }
  }

  const remote = await readGistBody(g);
  const localAt = state.updatedAt || 0;
  const remoteAt = remote?.updatedAt || 0;
  const takeRemote = prefer === 'remote' ? !!remote : prefer === 'auto' && remote && remoteAt >= localAt;

  if (takeRemote) {
    hydrate(remote);
    gh.lastSync = Date.now();
    setStatus('synced', `Synced as @${gh.user.login} · pulled from Gist`);
    toast(`Loaded @${gh.user.login}'s progress from GitHub`, 'ok');
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
    const remote = await readGistBody(await api(`/gists/${gh.gistId}`));
    if (remote) { hydrate(remote); toast('Pulled latest from GitHub', 'ok'); }
    gh.lastSync = Date.now();
    setStatus('synced', `Synced as @${gh.user?.login} · just now`);
  } catch (e) {
    setStatus('error', errorText(e));
    toast(`Pull failed — ${errorText(e)}`, 'err');
  }
}

/** Forget the token here. The Gist and its contents stay on GitHub, untouched. */
export function disconnect({ forgetDevice = true } = {}) {
  ls.del(gistKey());     // drops this account's remembered Gist id
  clearSessionToken();
  if (forgetDevice) clearVault();
  gh.token = null; gh.user = null; gh.gistId = null;
  setStatus('local', 'Local only — progress stays in this browser');
}

export const vaultState = () => ({ saved: hasVault(), crypto: cryptoAvailable() });

/** Unlock a passphrase-protected token and connect with it. */
export async function unlock(passphrase) {
  const token = await openVault(passphrase);
  return connect(token, { prefer: 'remote' });
}

/**
 * On load: use the tab's own session token if there is one. A token saved
 * behind a passphrase is NOT auto-opened — it waits for the passphrase.
 */
export async function restore() {
  if (purgeLegacyToken()) {
    toast('Removed a clear-text token left by an older version — reconnect to continue syncing', 'err');
  }
  const token = getSessionToken();
  if (!token) {
    if (hasVault()) setStatus('locked', 'Saved on this device — unlock in Settings to sync');
    return false;
  }
  try {
    await connect(token, { prefer: 'remote' });
    return true;
  } catch (e) {
    clearSessionToken();
    setStatus(hasVault() ? 'locked' : 'error', `${errorText(e)} Reconnect in Settings.`);
    return false;
  }
}
