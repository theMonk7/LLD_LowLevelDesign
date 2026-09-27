# Module 08 — Solutions & Reasoning

Each answer states **what varies** first, because that's the transferable part.

| # | Answer | What varies | Reasoning |
|---|---|---|---|
| 01 | **Strategy** | the cost algorithm, by carrier | Carriers are open-ended and only the computation differs. A closure would do if you never need the carrier's name; the moment receipts or audit need it, use the protocol. |
| 02 | **State** | every method's behaviour, by status | "Every method starts with a status check" is *the* State signature. Four states with rich rules justify one type per state; for four trivial states, an `enum` + one `transition(on:)` is defensible — say so. |
| 03 | **Observer** | the set of listeners, at runtime | Subject must not know its listeners. In production: `Combine`/`AsyncStream`; in an interview: hand-rolled with weak storage. |
| 04 | **Command** | the request itself becomes an object | Undo needs operations to be first-class. "Apply filter" isn't arithmetically reversible, so those commands hold a Memento — Command + Memento is the standard pair. |
| 05 | **Adapter** | the interface shape, units and error model | You own the caller, not the SDK. Three translations: names, paise↔rupees, status↔`throws`. |
| 06 | **Decorator** | stackable optional behaviour | "Without editing it" + "independently toggleable" = decorators, composed at the composition root. |
| 07 | **No pattern** | nothing yet | Swift's default arguments and named parameters already solve this. A Builder here is ceremony. |
| 08 | **Builder** | construction is incremental + cross-field validation | The two conditions that justify Builder in Swift. Note the builder must be a *class*, or the three functions mutate copies. |
| 09 | **Singleton** | nothing — there's exactly one | Immutable and read-only, so the usual objections mostly don't apply. Still expose it behind a protocol and inject with a default parameter. |
| 10 | **Composite** | one vs many, uniformly | Menus contain menus; pricing recurses. Put `add` on the composite, not the leaf, to avoid the LSP problem. |
| 11 | **Chain of Responsibility** | which handler handles it | Stop-at-first-handler flavour. Decide the terminal case: reject, escalate, or error. |
| 12 | **Flyweight** | nothing — state is shared | 200k instances, 12 distinct icons: intrinsic state (the icon) shared, extrinsic state (coordinates) per pin. At 200 pins you would not bother. |
| 13 | **Proxy** (protection) | access, not behaviour | Interface unchanged, caller asked for no new capability — that's Proxy, not Decorator. |
| 14 | **Mediator** | the coordination rules | Ten controls referencing each other is 45 edges; through a mediator it's ten. Keep business rules out of it or it becomes a God Object. |
| 15 | **Visitor** | the set of operations, over stable types | Types fixed, operations growing — the exact axis Visitor optimises. In Swift, an `enum` with exhaustive switches gives the same property with less ceremony; Visitor wins when the node types must be extensible across modules. Both answers are defensible in an interview; the grader takes Visitor because the drill says the type set is fixed and operations keep arriving. |
| 16 | **Null Object** | presence of a collaborator | Safe precisely because doing nothing is harmless. A no-op *payment* processor would be a disaster. |
| 17 | **Object Pool** | nothing — instances are reused | Expensive to create, safe to reuse, bursty traffic. Answer the three questions: exhaustion policy, reset on release, leak protection. |
| 18 | **No pattern** | the comparator, trivially | `sorted(by:)` is Strategy already, provided by the standard library. Writing a `SortStrategy` protocol here is Golden Hammer. |
| 19 | **Memento** | the state snapshot | Whole-state capture, restored later, with the caretaker unable to read it. Cost is memory; for a board game that's fine. |
| 20 | **Abstract Factory** | the family, atomically | The requirement is *consistency*, which is exactly what distinguishes Abstract Factory from Factory Method. |
| 21 | **Dependency Injection** | who chooses the implementation | The DIP fix. "I can't test it" is almost always this answer. |
| 22 | **Iterator** | traversal order | In Swift: two `Sequence` conformances, which also hands you `map`/`filter`/`prefix` free. |
| 23 | **Template Method** | one step inside a fixed skeleton | Steps and order fixed, one step varies — not Strategy, which would swap the whole algorithm. Strategy *injected into* a template is also valid; mention it. |
| 24 | **Facade** | nothing — it's a convenience | Delegation only. The moment it decides *whether* to extract audio, it has rules and is turning into a God Object. |
| 25 | **Bridge** | two independent dimensions | 5+4 = 9 types instead of 20. The tell is the multiplication in the problem statement. |
| 26 | **Prototype** | construction cost | Built once, copied often. If the template were a `struct`, `var copy = template` is already Prototype — say that; it shows Swift fluency. |
| 27 | **Factory Method** | which concrete parser | "Plugins may add extensions at runtime" makes the set open, ruling out a fixed enum + switch. A closure registry is the idiomatic Swift form of the same answer. |
| 28 | **No pattern** | nothing | A free function, or an extension on `Double`. Two call sites is not an extension axis. |
| 29 | **Chain of Responsibility** | which stage rejects it | The middleware flavour: *every* handler runs unless one rejects, versus drill 11 where the first capable handler stops the chain. Same pattern, two flavours — name which you're building. |
| 30 | **No pattern** | nothing | A `struct` with a failable initialiser. Making illegal states unrepresentable is a language feature, not a pattern. |

## The patterns behind the patterns

Three lessons across the 30:

1. **Four answers are "no pattern".** In a real interview, roughly that proportion of "should I use a pattern here?" moments should end in *no*. Candidates who never say no look insecure, not thorough.
2. **Several drills differ only in one clause** (07 vs 08, 11 vs 29, 13 vs 06). The pattern follows the *constraint*, not the domain. Train yourself to hunt for the deciding clause.
3. **Swift changes some answers.** Prototype for structs, Iterator as `Sequence`, Strategy as a closure, Visitor as an enum, Singleton as `static let`. Giving the Java answer in a Swift interview is a missed signal.

## If you scored…
- **27–30** — ready for Module 09.
- **22–26** — re-read the §2 symptom table and redo the ones you missed.
- **below 22** — re-read Modules 05–07 summaries, then redo all 30. Recall speed matters more here than depth.
