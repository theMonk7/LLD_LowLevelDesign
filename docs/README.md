# LLD Mastery — learning dashboard

A static site that turns this repo into a trackable curriculum: every `CONCEPTS.md`, `README.md`,
`EXERCISES.md`, `PROJECT.md` and `SOLUTIONS.md` is sliced into items you can tick off, star, tag,
annotate and attach links to. Progress is stored in a private GitHub Gist so it follows you across
browsers and machines.

## Run it locally

```bash
python3 -m http.server 8777 --directory docs
# open http://127.0.0.1:8777/
```

Opening `index.html` straight off disk will not work — `fetch()` of the JSON data needs HTTP.

## Host it on GitHub Pages

Two options:

1. **Zero config** — Settings → Pages → Source: *Deploy from a branch* → `main` / `/docs`.
   The generated data is committed, so nothing has to run in CI.
2. **Auto-regenerating** — Settings → Pages → Source: *GitHub Actions*.
   [`.github/workflows/pages.yml`](../.github/workflows/pages.yml) re-runs the content build on every
   push so edits to the module markdown show up on the site without a manual rebuild.

## Getting around

A module opens on an overview of its sections. Click one and it fills the page, with the other
sections becoming a sticky vertical rail on the right for switching without going back. Each section
shows the reading and video links that belong to it — the same links the Resources page files under
that section — and you can add more at section, item or general level.

Anything you add yourself (modules, sections, topics) sits alongside the generated curriculum, counts
towards progress, and syncs with everything else. Use **+ New module** on the dashboard or in the
sidebar, then **+ Add topic** inside any section. Topic bodies are markdown, including `swift` code
fences and `mermaid` diagrams.

## Taking notes

Every item has a notes box that saves as you type. **⤢ Expand** opens the same note full-screen with
a markdown preview, which beats scrolling a small box for anything long. Selecting any passage of an
item's text pops up **✎ Note this** — it appends that passage to the item's note as a markdown
blockquote and opens the editor with the cursor after it.

## Rebuild the content after editing module markdown

```bash
node tools/build-content.mjs     # regenerate docs/data from the module markdown
node tools/set-version.mjs       # bump the cache-busting ?v= on every asset
```

`set-version.mjs` stamps one version onto `index.html` **and** onto each internal
`import … from './x.js'`. Both matter: versioning only `app.js` lets a browser pair fresh app code
with a cached `store.js`, which fails at load with a missing-export error.

It writes `docs/data/content.json` (index: modules, sections, item titles, tags, seeded links) and
`docs/data/modules/mNN.json` (the markdown bodies, fetched lazily per module).

## Sync across browsers (GitHub Gist)

Settings → *Cross-browser sync*. Paste a personal access token:

- classic token with the **`gist`** scope, or
- fine-grained token with **Account permissions → Gists → Read and write**.

The dashboard finds a Gist containing `lld-dashboard-state.json`, or creates a private one. **The token
is the account** — a different token means a different Gist and therefore a separate set of progress,
notes, tags and links. The remembered Gist id is stored per account login, and its owner is verified
before anything is written, so two accounts used in the same browser never touch each other's data.
A Gist deleted on github.com is simply recreated on the next connect.

**Security.** The token lives in this browser's `localStorage` and is sent only to `api.github.com`.
Anyone with access to the browser profile can read it, so scope it to gists only and revoke it from
GitHub settings if the machine is shared. Without a token everything still works, stored locally.

## Resets

| Action | Clears | Keeps |
|---|---|---|
| Reset module (module page) | ticks in that module | notes, tags, favourites, links, your modules |
| Reset all progress (dashboard / settings) | every tick | notes, tags, favourites, links, your modules |
| Erase everything (settings) | everything, including notes and your own modules | — |

Settings also has JSON export/import if you want a backup independent of GitHub.

## Layout

```
docs/
├── index.html
├── assets/css/app.css
├── assets/js/
│   ├── app.js        router, event delegation, modals
│   ├── store.js      content index + user state + progress maths
│   ├── gist.js       GitHub Gist backend
│   ├── views.js      dashboard / module / browse / resources / settings
│   ├── md.js         markdown → HTML, Swift highlighting, Mermaid
│   └── util.js       DOM, toasts, modals, progress rings
└── data/             generated — do not edit by hand
```

Reading and video links are seeded from the [Krucible LLD sheet](https://krucible.netlify.app/) and
matched to the corresponding concept or problem; seeded links can be edited or removed per item, and
your changes are stored as an overlay so a content rebuild never overwrites them.
