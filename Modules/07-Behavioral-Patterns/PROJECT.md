# Module 07 Project — Text Editor with Undo/Redo and a State-Driven Toolbar

**Time:** 4–5 hours. The most pattern-dense project in the course; it's deliberately close to a real machine-coding round.

## Brief

> Build the core of a text editor (no UI). It supports typing, deleting, replacing, and formatting commands (uppercase, lowercase, trim). Every action is undoable and redoable. The editor has modes — `viewing`, `editing`, `selecting` — and available actions depend on the mode. A toolbar and a status bar observe the editor and update whenever anything changes. Documents can be exported to plain text, markdown, and HTML. Large documents should snapshot efficiently. An autosave component saves every N operations.

## Requirements mapped to patterns (state which you used and why)

1. **Undo/redo** for every action, with a redo stack that clears on a new action → **Command**
2. **Formatting operations that aren't arithmetically reversible** → **Memento** inside the command
3. **Modes** changing which actions are legal → **State** (no `switch` on mode)
4. **Toolbar + status bar + autosave** all react to editor changes → **Observer** (weak, safe re-entrancy)
5. **Export formats** over a fixed document-node hierarchy → **Visitor**, or an enum + exhaustive switch (pick one and defend it)
6. **A "macro" that runs several commands and undoes them as one** → **Composite** over Command
7. **Optional spellchecker dependency** → **Null Object**
8. **Document traversal** (words, lines, paragraphs) → **Iterator** via `Sequence`
9. **Input validation pipeline** (length → forbidden chars → rate limit) → **Chain of Responsibility**
10. **Save pipeline with fixed steps, one of which varies by format** → **Template Method**

You must use **at least seven** of these, and for each write one sentence on what breaks without it. Marks are deducted for patterns the requirements don't justify.

## Acceptance scenarios
| # | Scenario | Expected |
|---|---|---|
| 1 | Type 3 words, undo twice, redo once | text matches exactly |
| 2 | Undo, then type something new, then redo | redo does nothing; the new text stands |
| 3 | Uppercase then undo | original casing restored |
| 4 | Macro: "trim + uppercase + append signature", then one undo | all three reversed together |
| 5 | Switch to `viewing`, try to type | rejected with a mode-specific message; no state change |
| 6 | Any mutation | toolbar and status bar both updated exactly once |
| 7 | An observer deallocates | ticker/editor doesn't crash and stops tracking it |
| 8 | An observer unsubscribes while being notified | no crash; other observers still notified |
| 9 | Export the same document to 3 formats | correct output; adding a 4th format touches no node type |
| 10 | Input with forbidden characters | rejected by the right handler in the chain |
| 11 | Autosave after every 5 operations | fires at 5 and 10, not at 3 |
| 12 | No spellchecker injected | everything works, no `if let` at call sites |

## Deliverables
1. Source files: `Editor.swift`, `Commands.swift`, `States.swift`, `Observers.swift`, `Export.swift`.
2. `demo()` exercising all 12 scenarios with printed output.
3. Tests covering: undo/redo ordering, redo invalidation, macro atomicity, mode rejection, observer memory and re-entrancy, each export format.
4. Mermaid class diagram **and** a state diagram for the modes.
5. Decision log: 10–14 bullets, including at least one pattern you considered and rejected, and one place where you deliberately used no pattern.

## Rubric (/60)
| Criterion | 0 | 3 | 5 |
|---|---|---|---|
| Command: execute/undo correct | broken | happy path | all ordering cases |
| Redo invalidation | missing | partial | correct |
| Memento for irreversible ops | none | partial | snapshot-based undo works |
| Macro command atomicity | none | partial | undoes in reverse, as one |
| State: no `switch` on mode | switch remains | partial | one type per mode |
| Illegal actions rejected per mode | crash/ignore | partial | clear message, no state change |
| Observer: weak + re-entrancy safe | strong refs | weak only | weak + snapshot + purge |
| Exactly-once notification | duplicates | partial | idempotent subscribe |
| Export: new format, zero node edits | edits needed | 1 edit | zero |
| Chain of Responsibility with terminal case | none | partial | ordered + terminal |
| Template Method: skeleton fixed | duplicated | partial | one skeleton, varying step |
| Tests | none | happy path | failure + memory + ordering |
| Diagrams | absent | one | class + state, correct notation |
| Decision log incl. a rejection | absent | thin | tradeoffs, rejection, deliberate non-use |

**48+/60** → Module 08.

## Extension questions
1. Collaborative editing: two users type simultaneously. Which of your patterns survives, and what new concept do you need? (CRDT/OT — out of scope, but name the problem.)
2. Undo across a save boundary — should undo cross it? What does your `CommandHistory` need to know that it currently doesn't?
3. Your observers fire synchronously. What breaks if one is slow, and what would you change? (Module 09.)
4. You used Visitor (or an enum). Re-argue the opposite choice as strongly as you can.
5. Which single pattern here gave the worst value-for-complexity? Delete it and describe the resulting code.

Ask me to review your implementation against this rubric.
