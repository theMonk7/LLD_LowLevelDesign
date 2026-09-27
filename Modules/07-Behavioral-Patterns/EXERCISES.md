# Module 07 — Exercises

Fill in [`Code/Exercises.swift`](Code/Exercises.swift). Run `swift test --filter M07`. This is the largest exercise set in the course — budget 3 hours.

### E1 — Strategy
Three pricing strategies plus a lot that swaps them at runtime. The grader passes in a strategy defined inside the test.

### E2 — State ⭐ the big one
A vending machine with **four state types and zero `switch` statements**. Each state owns its own transitions; the machine owns the data. Watch the edge cases the grader checks: double coin, actions during dispensing, last item → sold out, selecting with zero stock.

### E3 — Observer ⭐ the tricky one
Weak storage, idempotent subscribe, safe unsubscribe **during** notification, and automatic purging of deallocated observers. Four of the five tests are about memory and re-entrancy, not about notification — because that's where real implementations break.

### E4 — Command + Memento
Undo/redo with a redo stack that clears on a new action. `UppercaseCommand` isn't arithmetically reversible, so it snapshots — that contrast between the two commands is the exercise.

### E5 — Chain of Responsibility
Three approvers with limits, a default extension holding the pass-on logic, and a terminal "rejected" case. `buildChain` wires them; reordering changes routing.

### E6 — Template Method
Protocol + extension form. `run` is the fixed skeleton; `parse` is required; `validate` is a hook with a default that `RawImporter` overrides.

### E7 — Iterator
Depth-first and breadth-first over the same tree, both as `Sequence` conformances. The last test proves the payoff: `filter`, `reduce` and `prefix` work for free.

### E8 — Mediator
Users never reference each other; the room coordinates. Sending from an unregistered user must be safe.

### E9 — Null Object
A do-nothing analytics implementation as the default parameter.

### E10 — Identification
Map each scenario to its pattern.

## Stretch (not graded)
1. Rewrite E2 as an `enum` state machine with one `transition(on:)` function. Which version would you ship for 4 states? For 15?
2. Make E3's ticker generic over the event type, and then rewrite it with `AsyncStream`. What did structured concurrency give you for free?
3. Add a `MacroCommand` to E4 that holds several commands and undoes them in reverse. Which structural pattern did you just use?
4. Give E5's chain the "every handler runs" flavour (middleware). What changes in the protocol?
5. Implement a `ShapeVisitor` for area and SVG export, then implement the same thing with an `enum` + `switch`. Write down which you'd defend in an interview and why.
