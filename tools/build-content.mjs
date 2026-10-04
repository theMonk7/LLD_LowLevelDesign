#!/usr/bin/env node
// Builds docs/data/content.json from Modules/**/*.md + the vendored Krucible LLD sheet.
// Run: node tools/build-content.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const MODULES_DIR = path.join(ROOT, 'Modules');
const OUT = path.join(ROOT, 'docs', 'data', 'content.json');
const SHEET = JSON.parse(fs.readFileSync(path.join(ROOT, 'tools', 'krucible-lld-sheet.json'), 'utf8'));

const PHASES = [
  { id: 'p1', title: 'Phase 1 — Foundations', modules: ['00', '01', '02', '03', '04'] },
  { id: 'p2', title: 'Phase 2 — Patterns', modules: ['05', '06', '07', '08', '09'] },
  { id: 'p3', title: 'Phase 3 — Problem Solving', modules: ['10', '11', '12', '13'] },
  { id: 'p4', title: 'Phase 4 — Applied & Interview', modules: ['14', '15'] },
];

const DIFFICULTY = { '11': 'easy', '12': 'medium', '13': 'hard' };

const PATTERN_WORDS = [
  'Singleton', 'Factory Method', 'Abstract Factory', 'Builder', 'Prototype', 'Object Pool',
  'Dependency Injection', 'Adapter', 'Bridge', 'Composite', 'Decorator', 'Facade', 'Flyweight',
  'Proxy', 'Chain of Responsibility', 'Command', 'Iterator', 'Mediator', 'Memento', 'Observer',
  'State', 'Strategy', 'Template Method', 'Visitor', 'Null Object', 'Coordinator', 'Repository',
  'MVVM', 'VIPER', 'Clean Architecture',
];

/* ----------------------------------------------------------------- helpers */

const slug = (s) =>
  String(s)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60);

const read = (p) => (fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : null);

/** Strip a leading `# Title` line, return { title, body }. */
function splitTitle(md) {
  const m = md.match(/^#\s+(.+?)\s*$/m);
  if (!m || md.slice(0, m.index).trim()) return { title: null, body: md };
  return { title: m[1], body: md.slice(m.index + m[0].length) };
}

/**
 * Split markdown into { title, level, body } blocks at the given heading levels,
 * ignoring headings inside fenced code blocks. Text before the first heading is
 * returned as `preamble`.
 */
function sectionize(md, levels) {
  const lines = md.split('\n');
  const out = [];
  let preamble = [];
  let current = null;
  let fence = null;
  for (const line of lines) {
    const f = line.match(/^(\s*)(`{3,}|~{3,})/);
    if (f) {
      const tick = f[2][0];
      if (!fence) fence = tick;
      else if (fence === tick) fence = null;
    }
    const h = !fence && line.match(/^(#{1,6})\s+(.+?)\s*$/);
    if (h && levels.includes(h[1].length)) {
      if (current) out.push(current);
      current = { title: h[2].trim(), level: h[1].length, lines: [] };
      continue;
    }
    (current ? current.lines : preamble).push(line);
  }
  if (current) out.push(current);
  return {
    preamble: preamble.join('\n').trim(),
    blocks: out.map((b) => ({ title: b.title, level: b.level, body: b.lines.join('\n').trim() })),
  };
}

/** Inline markdown has no place in a card title: `code`, *em*, **strong**, [links]. */
function plainText(s) {
  return String(s)
    .replace(/!?\[([^\]]*)\]\([^)]*\)/g, '$1')
    .replace(/`([^`]+)`/g, '$1')
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/(^|[\s(])\*([^*]+)\*/g, '$1$2')
    .replace(/(^|[\s(])_([^_]+)_/g, '$1$2')
    .replace(/\s+/g, ' ')
    .trim();
}

/** Clean a heading into a display title: drop numbering prefixes and the ⭐ marker. */
function cleanTitle(raw) {
  return plainText(raw)
    .replace(/\s*⭐.*$/, '')
    .replace(/^\d+\.\s*/, '')
    .replace(/^(SOLVED|DESIGN-ONLY|SOLO|Mock|E)\s*(\d+)\s*[—–-]\s*/i, (_, kind, n) =>
      kind.toUpperCase() === 'E' ? `E${n} — ` : `${kind} ${n} — `)
    .trim();
}

function detectTags(title, body, extra = []) {
  const tags = new Set(extra);
  const hay = `${title}\n${body.slice(0, 1500)}`;
  for (const p of PATTERN_WORDS) {
    if (new RegExp(`\\b${p.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`).test(hay)) tags.add(p);
  }
  if (/\b(actor|NSLock|DispatchQueue|race condition|thread[- ]safe|Sendable)\b/i.test(hay)) tags.add('Concurrency');
  if (/```mermaid/.test(body)) tags.add('UML');
  if (/```swift/.test(body)) tags.add('Code');
  return [...tags];
}

/* ------------------------------------------------------------ item builder */

/** `E1`, `SOLO 1`, `Mock 3` → a stable code shared by an exercise and its solution. */
const exerciseCode = (raw) => String(raw).toUpperCase().replace(/[^A-Z0-9]/g, '');

const codesIn = (title) =>
  [...String(title).matchAll(/\b(E\s*\d+|SOLO\s*\d+|MOCK\s*\d+)\b/gi)].map((m) => exerciseCode(m[1]));

const moduleAnswers = new Map();

/* Words that say nothing about which topic a heading is about. */
const NOISE = new Set([
  'the', 'a', 'an', 'and', 'or', 'of', 'to', 'in', 'on', 'for', 'is', 'it', 'its', 'as', 'at', 'by',
  'that', 'this', 'with', 'from', 'about', 'into', 'over', 'not', 'but', 'you', 'your', 'we', 'i',
  'what', 'why', 'how', 'when', 'who', 'which', 'where', 'all', 'one', 'two', 'most', 'more', 'than',
  'vs', 'versus', 'swift', 'swifts', 'principle', 'principles', 'pattern', 'patterns', 'module',
  's', 't', 're', 'll', 'be', 'are', 'was', 'does', 'do', 'can', 'they', 'them', 'their', 'really',
]);

const topicWords = (title) => new Set(
  plainText(title).toLowerCase().replace(/[^a-z0-9\s-]/g, ' ').split(/[\s-]+/)
    .filter((w) => w.length > 2 && !NOISE.has(w)),
);

/**
 * A concept heading and a reference heading that are about the same topic become
 * one card. Matching is deliberately strict: the smaller word set has to be
 * almost contained in the larger, so "Encapsulation is not 'use private'" pairs
 * with "Encapsulation", while "Building versus constructing" never pairs with
 * "Builder".
 */
function pairTopics(conceptItems, theoryItems) {
  const pairs = [];
  for (const c of conceptItems) {
    const cw = topicWords(c.title);
    if (!cw.size) continue;
    for (const t of theoryItems) {
      const tw = topicWords(t.title);
      if (!tw.size) continue;
      let shared = 0;
      for (const w of cw) if (tw.has(w)) shared += 1;
      if (!shared) continue;
      const score = shared / Math.min(cw.size, tw.size);
      if (score >= 0.6) pairs.push({ c, t, score, shared });
    }
  }
  pairs.sort((a, b) => b.score - a.score || b.shared - a.shared);

  const byConcept = new Map();
  const usedTheory = new Set();
  for (const p of pairs) {
    if (byConcept.has(p.c.id) || usedTheory.has(p.t.id)) continue;
    byConcept.set(p.c.id, p.t);
    usedTheory.add(p.t.id);
  }
  return byConcept;
}

function mergeInto(theoryItem, conceptItem) {
  theoryItem.body = `## Mental model\n\n${conceptItem.body}\n\n---\n\n## Reference\n\n${theoryItem.body}`;
  theoryItem.tags = [...new Set([...conceptItem.tags, ...theoryItem.tags])];
  theoryItem.trackable = theoryItem.trackable || conceptItem.trackable;
  // the concept card's id disappears; keep it so saved progress can follow
  theoryItem.aliases = [...(theoryItem.aliases || []), conceptItem.id];
}

/**
 * Mental models and the module reference, as one section. Topics covered by both
 * files share a single card — mental model first, then the reference.
 */
function pushTheory(sections, conceptItems, theoryItems, files) {
  const paired = pairTopics(conceptItems, theoryItems);
  for (const c of conceptItems) {
    const t = paired.get(c.id);
    if (t) mergeInto(t, c);
  }
  const conceptOnly = conceptItems.filter((c) => !paired.has(c.id));
  const items = [...conceptOnly, ...theoryItems];
  if (!items.length) return;
  for (const it of items) it.group = null;      // one flat list of topics

  const source = [files.concepts ? 'CONCEPTS.md' : null, files.readme ? 'README.md' : null]
    .filter(Boolean).join(' · ');
  sections.push({ id: 'theory', title: 'Theory', kind: 'theory', source, items });
}

let counter = 0;
function makeItem({ moduleId, sectionId, title, body, kind, group, trackable = true, difficulty = null, tags = [] }) {
  counter += 1;
  return {
    id: `${moduleId}.${sectionId}.${slug(title) || `i${counter}`}`,
    title,
    kind,
    group: group || null,
    trackable,
    difficulty,
    tags: detectTags(title, body, tags),
    body,
    resources: [],
  };
}

/* --------------------------------------------------------- module assembly */

function buildModule(dirName) {
  const num = dirName.slice(0, 2);
  const dir = path.join(MODULES_DIR, dirName);
  const moduleId = `m${num}`;
  const difficulty = DIFFICULTY[num] || null;
  const phase = PHASES.find((p) => p.modules.includes(num));

  const files = {
    concepts: read(path.join(dir, 'CONCEPTS.md')),
    readme: read(path.join(dir, 'README.md')),
    exercises: read(path.join(dir, 'EXERCISES.md')),
    solutions: read(path.join(dir, 'SOLUTIONS.md')),
    project: read(path.join(dir, 'PROJECT.md')),
  };

  const readmeTitle = files.readme ? splitTitle(files.readme).title : dirName;
  const title = plainText(readmeTitle || dirName)
    .replace(/^Module\s+\d+\s*[—–-]\s*/i, '')
    .replace(/\s*\([^)]*\)\s*$/, '')
    .trim();

  const sections = [];
  // Mental models and the reference read as one body of theory, so they are
  // collected first and pushed as a single section with two groups.
  const conceptItems = [];

  /* 1 — Mental models (CONCEPTS.md) */
  if (files.concepts) {
    const { body } = splitTitle(files.concepts);
    const { preamble, blocks } = sectionize(body, [2]);
    const items = [];
    if (preamble) {
      items.push(makeItem({
        moduleId, sectionId: 'concepts', title: 'Orientation', body: preamble,
        kind: 'concept', group: 'Mental models', difficulty, tags: ['Mental model'],
      }));
    }
    for (const b of blocks) {
      items.push(makeItem({
        moduleId, sectionId: 'concepts', title: cleanTitle(b.title), body: b.body,
        kind: 'concept', group: 'Mental models', trackable: !/checkpoint/i.test(b.title),
        difficulty, tags: ['Mental model'],
      }));
    }
    conceptItems.push(...items);
  }

  /* 2 — Theory (README.md) + 3 — Problems when the module is a problem set */
  if (files.readme) {
    const { body } = splitTitle(files.readme);
    const hasProblems = /^#\s+(SOLVED|DESIGN-ONLY)\s+\d+/m.test(body);

    if (hasProblems) {
      const { preamble, blocks } = sectionize(body, [1]);
      const theory = [];
      const problems = [];
      if (preamble) {
        theory.push(makeItem({
          moduleId, sectionId: 'theory', title: 'How to use this module', body: preamble,
          kind: 'theory', group: 'Reference', difficulty,
        }));
      }
      for (const b of blocks) {
        const m = b.title.match(/^(SOLVED|DESIGN-ONLY)\s+(\d+)\s*[—–-]\s*(.+)$/i);
        if (m) {
          const group = m[1].toUpperCase() === 'SOLVED' ? 'Solved walkthroughs' : 'Design-only walkthroughs';
          problems.push(makeItem({
            moduleId, sectionId: 'problems', title: plainText(m[3]).replace(/\s*⭐.*$/, '').trim(), body: b.body,
            kind: 'problem', group, difficulty,
            tags: [m[1].toUpperCase() === 'SOLVED' ? 'Solved' : 'Design-only', /⭐/.test(b.title) ? 'Must-know' : null].filter(Boolean),
          }));
        } else {
          theory.push(makeItem({
            moduleId, sectionId: 'theory', title: cleanTitle(b.title), body: b.body,
            kind: 'theory', group: 'Reference', trackable: !/checkpoint/i.test(b.title), difficulty,
          }));
        }
      }
      pushTheory(sections, conceptItems, theory, files);
      if (problems.length) sections.push({ id: 'problems', title: 'Problems', kind: 'problem', source: 'README.md', items: problems });
    } else {
      const { preamble, blocks } = sectionize(body, [2]);
      const items = [];
      if (preamble) {
        items.push(makeItem({
          moduleId, sectionId: 'theory', title: 'Overview', body: preamble,
          kind: 'theory', group: 'Reference', difficulty,
        }));
      }
      for (const b of blocks) {
        items.push(makeItem({
          moduleId, sectionId: 'theory', title: cleanTitle(b.title), body: b.body,
          kind: 'theory', group: 'Reference', trackable: !/checkpoint/i.test(b.title), difficulty,
        }));
      }
      pushTheory(sections, conceptItems, items, files);
    }
  } else {
    pushTheory(sections, conceptItems, [], files);
  }

  /* 4 — Exercises (EXERCISES.md) */
  if (files.exercises) {
    const { body } = splitTitle(files.exercises);
    const { preamble, blocks } = sectionize(body, [2, 3]);
    const items = [];
    if (preamble) {
      items.push(makeItem({
        moduleId, sectionId: 'exercises', title: 'Exercise brief', body: preamble,
        kind: 'note', trackable: false, difficulty,
      }));
    }
    for (const b of blocks) {
      const m = b.title.match(/^(E|SOLO|Mock|Exercise)\s*(\d+)\s*[—–-]?\s*(.*)$/i);
      const isTask = !!m;
      const label = m ? `${m[1].toUpperCase() === 'E' ? `E${m[2]}` : `${m[1]} ${m[2]}`} — ${m[3] || 'Task'}` : b.title;
      const codeItem = makeItem({
        moduleId, sectionId: 'exercises', title: plainText(label).replace(/\s*⭐.*$/, '').trim(), body: b.body,
        kind: isTask ? 'exercise' : 'note',
        group: isTask ? (/^SOLO/i.test(b.title) ? 'Solo problems' : /^Mock/i.test(b.title) ? 'Mock interviews' : 'Graded exercises') : 'Extras',
        trackable: isTask,
        difficulty,
        tags: [/⭐/.test(b.title) ? 'Must-know' : null].filter(Boolean),
      });
      if (m) codeItem.code = exerciseCode(`${m[1]}${m[2]}`);
      items.push(codeItem);
    }
    if (items.length) sections.push({ id: 'exercises', title: 'Exercises', kind: 'exercise', source: 'EXERCISES.md', items });
  }

  /* 5 — Project (PROJECT.md) */
  if (files.project) {
    const { title: pTitle, body } = splitTitle(files.project);
    sections.push({
      id: 'project',
      title: 'Module Project',
      kind: 'project',
      source: 'PROJECT.md',
      items: [makeItem({
        moduleId, sectionId: 'project',
        title: plainText(pTitle || 'Project').replace(/^Module\s+\d+\s+Project\s*[—–-]\s*/i, '').trim(),
        body, kind: 'project', difficulty, tags: ['Project'],
      })],
    });
  }

  /* 6 — Solutions (SOLUTIONS.md). A block that names an exercise is attached to
     that exercise and revealed on demand; anything left over stays a section. */
  const answers = {};
  if (files.solutions) {
    const { body } = splitTitle(files.solutions);
    const { preamble, blocks } = sectionize(body, [2]);
    const exercises = (sections.find((x) => x.id === 'exercises') || { items: [] }).items;
    const leftovers = [];

    for (const b of blocks) {
      const codes = codesIn(b.title);
      const targets = codes.length ? exercises.filter((it) => it.code && codes.includes(it.code)) : [];
      if (targets.length) {
        for (const t of targets) {
          answers[t.id] = answers[t.id] ? `${answers[t.id]}\n\n${b.body}` : b.body;
          t.hasAnswer = true;
        }
      } else {
        leftovers.push(b);
      }
    }

    // Whatever names no exercise still belongs with the exercises, as a
    // spoiler-gated extra rather than a section of its own.
    const extras = [];
    if (preamble) {
      extras.push(makeItem({
        moduleId, sectionId: 'solutions', title: 'Before you read these', body: preamble,
        kind: 'solution', group: 'Solutions & commentary', trackable: false,
      }));
    }
    for (const b of leftovers) {
      extras.push(makeItem({
        moduleId, sectionId: 'solutions', title: cleanTitle(b.title), body: b.body,
        kind: 'solution', group: 'Solutions & commentary', trackable: false,
      }));
    }
    for (const x of extras) x.spoiler = true;

    if (extras.length) {
      let exSection = sections.find((x) => x.id === 'exercises');
      if (!exSection) {
        exSection = { id: 'exercises', title: 'Exercises', kind: 'exercise', source: 'EXERCISES.md', items: [] };
        const projectAt = sections.findIndex((x) => x.id === 'project');
        if (projectAt === -1) sections.push(exSection);
        else sections.splice(projectAt, 0, exSection);
      }
      exSection.source = `${exSection.source} · SOLUTIONS.md`;
      exSection.items.push(...extras);
    }
  }

  moduleAnswers.set(moduleId, answers);

  const allItems = sections.flatMap((s) => s.items);
  return {
    id: moduleId,
    num,
    slug: dirName,
    title,
    phaseId: phase ? phase.id : 'p1',
    difficulty,
    sections,
    totals: { items: allItems.length, trackable: allItems.filter((i) => i.trackable).length },
  };
}

/* -------------------------------------------- Krucible resource attachment */

const norm = (s) =>
  String(s)
    .toLowerCase()
    .replace(/^design\s+(a|an|the)?\s*/, '')
    .replace(/^(solved|design-only|solo|mock)\s*\d*\s*[—–-]?\s*/, '')
    .replace(/^[a-z]\s+[—–-]\s+/, '')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();

// Sheet entries whose wording does not line up with any repo heading.
const ALIASES = {
  'What is OOP?': { num: '01', match: 'What OOP actually is' },
  'Interface vs Abstract Class': { num: '01', match: "Protocols: Swift's interfaces" },
  'Coupling vs Cohesion': { num: '01', match: 'Coupling and Cohesion' },
  'Design Coffee Vending Machine': { num: '10', match: 'Timed design: drink vending machine' },
};

const SHEET_SECTION_TO_MODULE = {
  'OOP Fundamentals': '01',
  'SOLID Principles': '02',
  'Other Design Principles': '03',
  'UML Diagrams': '04',
  'Design Patterns — Creational': '05',
  'Design Patterns — Structural': '06',
  'Design Patterns — Behavioral': '07',
  'LLD Practice Problems': null, // spread across 11/12/13
};

function attachResources(modules) {
  const index = [];
  for (const m of modules) {
    for (const s of m.sections) {
      if (s.kind === 'solution') continue;
      for (const it of s.items) index.push({ module: m, item: it, n: norm(it.title) });
    }
  }
  const unmatched = [];

  for (const [sectionName, entries] of Object.entries(SHEET)) {
    if (sectionName === 'Additional Resources') continue;
    const preferNum = SHEET_SECTION_TO_MODULE[sectionName];
    for (const e of entries) {
      const n = norm(e.t);
      const links = [
        e.read ? { id: `seed-read-${slug(e.t)}`, type: 'read', label: 'Reading', url: e.read, seed: true } : null,
        e.watch ? { id: `seed-watch-${slug(e.t)}`, type: 'watch', label: 'Video', url: e.watch, seed: true } : null,
        e.practice ? { id: `seed-practice-${slug(e.t)}`, type: 'practice', label: 'Practice', url: e.practice, seed: true } : null,
      ].filter(Boolean);
      if (!links.length) { unmatched.push({ sectionName, e, reason: 'no-links' }); continue; }

      const alias = ALIASES[e.t];
      if (alias) {
        const target = index.find((x) => x.module.num === alias.num && x.item.title.includes(alias.match));
        if (target) {
          for (const l of links) if (!target.item.resources.some((r) => r.url === l.url)) target.item.resources.push(l);
          continue;
        }
      }

      const pool = preferNum ? index.filter((x) => x.module.num === preferNum) : index;
      let hit =
        pool.find((x) => x.n === n) ||
        pool.find((x) => x.n.startsWith(n) || n.startsWith(x.n)) ||
        pool.find((x) => x.n.includes(n) || n.includes(x.n));
      if (!hit && preferNum) {
        hit = index.find((x) => x.n === n) || index.find((x) => x.n.includes(n) || n.includes(x.n));
      }
      if (hit) {
        for (const l of links) if (!hit.item.resources.some((r) => r.url === l.url)) hit.item.resources.push(l);
      } else {
        unmatched.push({ sectionName, e, reason: 'no-item' });
      }
    }
  }
  return unmatched;
}

/* -------------------------------------------------------------------- main */

const dirs = fs
  .readdirSync(MODULES_DIR, { withFileTypes: true })
  .filter((d) => d.isDirectory() && /^\d\d-/.test(d.name))
  .map((d) => d.name)
  .sort();

const modules = dirs.map(buildModule);
const unmatched = attachResources(modules);

const extraResources = [
  ...(SHEET['Additional Resources'] || []).map((e) => ({
    id: `seed-extra-${slug(e.t)}`,
    title: e.t,
    url: e.read || e.watch || e.practice,
    type: e.watch ? 'watch' : 'read',
    seed: true,
  })),
  ...unmatched
    .filter((u) => u.reason === 'no-item' && (u.e.read || u.e.watch))
    .map((u) => ({
      id: `seed-extra-${slug(u.e.t)}`,
      title: `${u.e.t} (${u.sectionName})`,
      url: u.e.read || u.e.watch,
      type: u.e.watch && !u.e.read ? 'watch' : 'read',
      seed: true,
    })),
];

// Bodies live in per-module files so the first paint only pays for the index.
const BODY_DIR = path.join(ROOT, 'docs', 'data', 'modules');
fs.mkdirSync(BODY_DIR, { recursive: true });
fs.rmSync(BODY_DIR, { recursive: true, force: true });
fs.mkdirSync(BODY_DIR, { recursive: true });

for (const m of modules) {
  const bodies = {};
  for (const s of m.sections) {
    for (const it of s.items) {
      bodies[it.id] = it.body;
      delete it.body;
    }
  }
  fs.writeFileSync(path.join(BODY_DIR, `${m.id}.json`), JSON.stringify({
    id: m.id, bodies, answers: moduleAnswers.get(m.id) || {},
  }));
}

const out = {
  version: 1,
  generatedAt: new Date().toISOString(),
  source: { repo: 'LLD Mastery Track — Swift Edition', sheet: 'https://krucible.netlify.app/' },
  phases: PHASES.map((p) => ({ id: p.id, title: p.title })),
  modules,
  extraResources,
  stats: {
    modules: modules.length,
    items: modules.reduce((a, m) => a + m.totals.items, 0),
    trackable: modules.reduce((a, m) => a + m.totals.trackable, 0),
    seededLinks: modules.reduce((a, m) => a + m.sections.reduce((b, s) => b + s.items.reduce((c, i) => c + i.resources.length, 0), 0), 0),
    answers: [...moduleAnswers.values()].reduce((a, x) => a + Object.keys(x).length, 0),
  },
};

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(out));
const kb = (fs.statSync(OUT).size / 1024).toFixed(0);
const bodyKb = (fs.readdirSync(BODY_DIR).reduce((a, f) => a + fs.statSync(path.join(BODY_DIR, f)).size, 0) / 1024).toFixed(0);

console.log(`content.json  ${kb} KB  (index)   modules/*.json  ${bodyKb} KB (bodies)`);
console.log(`modules ${out.stats.modules} | items ${out.stats.items} | trackable ${out.stats.trackable} | seeded links ${out.stats.seededLinks} | answers ${out.stats.answers}`);
console.log(`unmatched sheet entries: ${unmatched.length}`);
for (const u of unmatched) console.log(`  - [${u.reason}] ${u.sectionName} / ${u.e.t}`);
