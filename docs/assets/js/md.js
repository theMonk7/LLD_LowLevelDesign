/* Markdown → sanitised HTML, with Swift syntax highlighting and lazy Mermaid. */

import { marked } from 'https://cdn.jsdelivr.net/npm/marked@12.0.2/lib/marked.esm.js';
import DOMPurify from 'https://cdn.jsdelivr.net/npm/dompurify@3.1.6/+esm';

let hljs = null;
let mermaidLib = null;
let mermaidTheme = null;

async function getHljs() {
  if (hljs) return hljs;
  const core = (await import('https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/lib/core/+esm')).default;
  const langs = await Promise.all([
    import('https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/lib/languages/swift/+esm'),
    import('https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/lib/languages/javascript/+esm'),
    import('https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/lib/languages/json/+esm'),
    import('https://cdn.jsdelivr.net/npm/highlight.js@11.9.0/lib/languages/bash/+esm'),
  ]);
  const names = ['swift', 'javascript', 'json', 'bash'];
  langs.forEach((m, i) => core.registerLanguage(names[i], m.default));
  hljs = core;
  return hljs;
}

marked.setOptions({ gfm: true, breaks: false, mangle: false, headerIds: false });

const renderer = new marked.Renderer();
renderer.code = (code, lang) => {
  if ((lang || '').toLowerCase() === 'mermaid') {
    return `<div class="mermaid" data-src="${encodeURIComponent(code)}">Loading diagram…</div>`;
  }
  const l = (lang || '').toLowerCase();
  return `<pre><code class="language-${l || 'plain'}">${code
    .replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]))}</code></pre>`;
};
renderer.link = (href, title, text) => {
  const safe = /^https?:\/\//i.test(href || '') ? href : '#';
  const ext = safe !== '#' ? ' target="_blank" rel="noopener noreferrer"' : '';
  return `<a href="${safe}"${ext}${title ? ` title="${title}"` : ''}>${text}</a>`;
};
marked.use({ renderer });

/** Render markdown to a sanitised HTML string. */
export function renderMarkdown(md) {
  const raw = marked.parse(md || '');
  return DOMPurify.sanitize(raw, {
    ADD_ATTR: ['target', 'rel', 'data-src'],
    ADD_TAGS: ['svg', 'path', 'g', 'rect', 'line', 'text', 'polygon', 'marker', 'defs'],
  });
}

/** Post-render pass: highlight code, draw Mermaid diagrams. */
export async function enhance(root) {
  const codes = [...root.querySelectorAll('pre code[class^="language-"]')]
    .filter((el) => !el.dataset.hl && !/language-plain/.test(el.className));
  if (codes.length) {
    const hl = await getHljs();
    for (const el of codes) {
      const lang = el.className.replace('language-', '');
      if (!hl.getLanguage(lang)) { el.dataset.hl = '1'; continue; }
      try {
        el.innerHTML = hl.highlight(el.textContent, { language: lang }).value;
      } catch { /* leave plain */ }
      el.dataset.hl = '1';
    }
  }

  const diagrams = [...root.querySelectorAll('.mermaid[data-src]')];
  if (!diagrams.length) return;
  const wantTheme = document.documentElement.dataset.mode === 'light' ? 'neutral' : 'dark';
  if (!mermaidLib) {
    mermaidLib = (await import('https://cdn.jsdelivr.net/npm/mermaid@10.9.1/dist/mermaid.esm.min.mjs')).default;
  }
  if (mermaidTheme !== wantTheme) {
    mermaidLib.initialize({ startOnLoad: false, securityLevel: 'strict', theme: wantTheme, fontFamily: 'inherit' });
    mermaidTheme = wantTheme;
  }
  for (const el of diagrams) {
    const src = decodeURIComponent(el.dataset.src);
    const id = `mmd${Math.random().toString(36).slice(2, 9)}`;
    try {
      const { svg } = await mermaidLib.render(id, src);
      el.innerHTML = svg;
    } catch (e) {
      el.innerHTML = `<pre><code>${src.replace(/[&<>]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]))}</code></pre>`;
    }
  }
}

/** Re-theme already-rendered diagrams after a light/dark switch. */
export function invalidateDiagrams(root = document) {
  mermaidTheme = null;
  root.querySelectorAll('.mermaid[data-src] svg').forEach((svg) => svg.remove());
}

/** Plain-text preview for search snippets. */
export function stripMd(md, max = 180) {
  const t = String(md || '')
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/[#*_`>|-]+/g, ' ')
    .replace(/\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/\s+/g, ' ')
    .trim();
  return t.length > max ? `${t.slice(0, max)}…` : t;
}
