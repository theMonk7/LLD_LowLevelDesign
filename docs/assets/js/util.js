/* Small DOM + formatting helpers shared by every view. */

export const $ = (sel, root = document) => root.querySelector(sel);
export const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];

export const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

export const pct = (done, total) => (total ? Math.round((done / total) * 100) : 0);

export function debounce(fn, ms) {
  let t;
  const wrapped = (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); };
  wrapped.flush = (...a) => { clearTimeout(t); fn(...a); };
  wrapped.cancel = () => clearTimeout(t);
  return wrapped;
}

export function timeAgo(ts) {
  if (!ts) return 'never';
  const s = Math.floor((Date.now() - ts) / 1000);
  if (s < 60) return 'just now';
  const units = [['min', 60], ['h', 60], ['d', 24], ['mo', 30], ['y', 12]];
  let v = s / 60, i = 0;
  while (i < units.length - 1 && v >= units[i + 1][1]) { v /= units[i + 1][1]; i += 1; }
  return `${Math.floor(v)}${units[i][0]} ago`;
}

export function fmtDate(ts) {
  if (!ts) return '—';
  return new Date(ts).toLocaleDateString(undefined, { day: 'numeric', month: 'short', year: 'numeric' });
}

/** Safe external link: only http(s) survives. */
export function safeUrl(u) {
  try {
    const url = new URL(String(u), location.href);
    return url.protocol === 'http:' || url.protocol === 'https:' ? url.href : null;
  } catch { return null; }
}

/* ------------------------------------------------------------ toasts */
export function toast(msg, kind = '') {
  const root = $('#toasts');
  const el = document.createElement('div');
  el.className = `toast ${kind}`;
  el.textContent = msg;
  root.appendChild(el);
  setTimeout(() => { el.style.opacity = '0'; el.style.transition = 'opacity .25s'; }, 2600);
  setTimeout(() => el.remove(), 2950);
}

/* ------------------------------------------------------------- modal */
let closeModalFn = null;

export function closeModal() { if (closeModalFn) closeModalFn(); }

/**
 * Open a modal. `render(close)` returns innerHTML; `onMount(root, close)` wires it up.
 */
export function modal({ render, onMount }) {
  const root = $('#modalRoot');
  root.hidden = false;
  root.innerHTML = `<div class="modal" role="dialog" aria-modal="true">${render()}</div>`;

  const close = () => {
    root.hidden = true;
    root.innerHTML = '';
    document.removeEventListener('keydown', onKey);
    root.removeEventListener('mousedown', onBack);
    closeModalFn = null;
  };
  const onKey = (e) => { if (e.key === 'Escape') close(); };
  const onBack = (e) => { if (e.target === root) close(); };

  document.addEventListener('keydown', onKey);
  root.addEventListener('mousedown', onBack);
  closeModalFn = close;

  if (onMount) onMount($('.modal', root), close);
  const first = $('input, textarea, select, button', root);
  if (first) first.focus();
  return close;
}

export function confirmModal({ title, body, confirmLabel = 'Confirm', danger = false, onConfirm }) {
  modal({
    render: () => `
      <h3>${esc(title)}</h3>
      <p class="hint">${body}</p>
      <div class="modal-actions">
        <button class="btn" data-x="cancel">Cancel</button>
        <button class="btn ${danger ? 'danger' : 'primary'}" data-x="ok">${esc(confirmLabel)}</button>
      </div>`,
    onMount: (root, close) => {
      $('[data-x="cancel"]', root).onclick = close;
      $('[data-x="ok"]', root).onclick = () => { close(); onConfirm(); };
    },
  });
}

/* --------------------------------------------------------- SVG rings */
export function ringSvg(value, size = 58, stroke = 6, showLabel = true) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const dash = (value / 100) * c;
  return `
  <svg class="ring" viewBox="0 0 ${size} ${size}" width="${size}" height="${size}" aria-hidden="true">
    <defs>
      <linearGradient id="ringGrad" x1="0" y1="0" x2="1" y2="1">
        <stop offset="0%" stop-color="var(--a)"/><stop offset="100%" stop-color="var(--a2)"/>
      </linearGradient>
    </defs>
    <circle class="bgc" cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke-width="${stroke}"/>
    <circle class="fgc" cx="${size / 2}" cy="${size / 2}" r="${r}" fill="none" stroke-width="${stroke}"
            stroke-dasharray="${dash} ${c}" transform="rotate(-90 ${size / 2} ${size / 2})"/>
    ${showLabel ? `<text class="ring-label" x="50%" y="50%" text-anchor="middle" dominant-baseline="central"
            style="font-size:${Math.round(size / 4.2)}px">${value}%</text>` : ''}
  </svg>`;
}

export function barHtml(value, cls = '') {
  return `<div class="bar ${cls}"><i style="width:${value}%"></i></div>`;
}
