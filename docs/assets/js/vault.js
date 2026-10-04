/* Where the GitHub token lives.

   What a browser can and cannot do, stated plainly:

   - There is no secret store a web page can use that its own JavaScript cannot
     read. While the dashboard is running and unlocked, any script executing in
     this origin can use the token. No scheme below changes that.
   - What IS worth fixing is the token sitting in localStorage in clear text,
     readable by anything that can reach the profile on disk, forever, with no
     action from you.

   So: by default the token lives in memory for the tab only (sessionStorage,
   gone when the tab closes). If you want it remembered across sessions, it is
   encrypted with AES-GCM under a key derived from a passphrase you type
   (PBKDF2-SHA256, 310k iterations) — at rest it is ciphertext, useless without
   the passphrase, which is never stored. */

const SESSION_KEY = 'lld.gh.session';
const VAULT_KEY = 'lld.gh.vault';
const LEGACY_KEY = 'lld.gh.token';
const ITERATIONS = 310000;

const enc = new TextEncoder();
const dec = new TextDecoder();

const b64 = (buf) => btoa(String.fromCharCode(...new Uint8Array(buf)));
const unb64 = (s) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));

const safe = {
  get(store, k) { try { return window[store].getItem(k); } catch { return null; } },
  set(store, k, v) { try { window[store].setItem(k, v); } catch { /* blocked */ } },
  del(store, k) { try { window[store].removeItem(k); } catch { /* blocked */ } },
};

export const cryptoAvailable = () => !!(window.crypto && window.crypto.subtle);

/* ------------------------------------------------- tab-scoped session */
export const getSessionToken = () => safe.get('sessionStorage', SESSION_KEY);
export const setSessionToken = (t) => safe.set('sessionStorage', SESSION_KEY, t);
export const clearSessionToken = () => safe.del('sessionStorage', SESSION_KEY);

/* ----------------------------------------------------- encrypted vault */
export const hasVault = () => !!safe.get('localStorage', VAULT_KEY);
export const clearVault = () => safe.del('localStorage', VAULT_KEY);

async function deriveKey(passphrase, salt) {
  const base = await crypto.subtle.importKey('raw', enc.encode(passphrase), 'PBKDF2', false, ['deriveKey']);
  return crypto.subtle.deriveKey(
    { name: 'PBKDF2', salt, iterations: ITERATIONS, hash: 'SHA-256' },
    base,
    { name: 'AES-GCM', length: 256 },
    false,                       // the derived key itself is non-extractable
    ['encrypt', 'decrypt'],
  );
}

export async function saveVault(token, passphrase) {
  if (!cryptoAvailable()) throw new Error('This browser has no Web Crypto (needs https or localhost).');
  if (!passphrase || passphrase.length < 8) throw new Error('Use a passphrase of at least 8 characters.');
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const key = await deriveKey(passphrase, salt);
  const ct = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, enc.encode(token));
  safe.set('localStorage', VAULT_KEY, JSON.stringify({
    v: 1, alg: 'AES-GCM', kdf: 'PBKDF2-SHA256', iterations: ITERATIONS,
    salt: b64(salt), iv: b64(iv), ct: b64(ct), savedAt: Date.now(),
  }));
}

/** Returns the token, or throws when the passphrase is wrong. */
export async function openVault(passphrase) {
  const raw = safe.get('localStorage', VAULT_KEY);
  if (!raw) throw new Error('Nothing saved on this device.');
  const box = JSON.parse(raw);
  const key = await deriveKey(passphrase, unb64(box.salt));
  try {
    const plain = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: unb64(box.iv) }, key, unb64(box.ct));
    return dec.decode(plain);
  } catch {
    throw new Error('Wrong passphrase.');
  }
}

/** A clear-text token from an older build is deleted on sight. */
export function purgeLegacyToken() {
  const old = safe.get('localStorage', LEGACY_KEY);
  if (!old) return false;
  safe.del('localStorage', LEGACY_KEY);
  return true;
}
