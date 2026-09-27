# Module 10 Project — The Framework, On the Clock

**Time:** three timed runs of 60 minutes each, on three different days. This is a *practice* project: the deliverable is the process, not a polished system.

## How to run it

For each problem below:

| Minutes | Step | Deliverable |
|---|---|---|
| 0–8 | **D** | in-scope / out-of-scope / non-functional lists + a one-paragraph restatement |
| 8–13 | **E** | actors, use cases, noun table with verdicts, verb→owner table, 2+ implied entities |
| 13–25 | **S** | Mermaid class diagram, multiplicity everywhere, `<<protocol>>` on each variation axis |
| 25–30 | **I** | public API of the root type + one sequence diagram |
| 30–35 | **G** | variation sentences + edge-case list from the §7 checklist |
| 35–55 | **N** | Swift: value types → entities → service → `demo()` |
| 55–60 | — | what you'd add next, written down |

**Set an actual timer, and stop at each boundary even if unfinished.** Learning to leave a step imperfect is part of the skill.

## The three problems

### Run 1 — Coffee Vending Machine
> A machine dispenses espresso, latte and cappuccino. Each recipe uses different amounts of water, milk and beans. The machine tracks ingredient levels and refuses drinks it can't make, telling the user what's missing. Operators refill ingredients and read a sales report.

Watch for: the implied `Recipe` and `Ingredient` entities, and the "what's missing" message pushing you toward returning a *reason* rather than a `Bool`.

### Run 2 — Browser History
> Back, forward, visit a new page (which clears the forward stack), and view the last N visited pages. Support multiple tabs, each with its own history, and a global "recently closed tabs" list.

Watch for: this is Command/Memento-shaped; the forward-stack-clearing rule is the same one as Module 07 E4.

### Run 3 — Task Scheduler
> Tasks have a name, a priority, an optional dependency on other tasks, and a run function. The scheduler runs ready tasks in priority order, never before their dependencies, and reports cycles as an error. Tasks can be cancelled before they start.

Watch for: cycle detection is the algorithmic bit, but the LLD content is the `Task` lifecycle state machine and where cancellation is enforced.

## Deliverables per run
1. `RunN.md` — the six step outputs, timestamped.
2. `RunN.swift` — whatever compiled by minute 55.
3. A retro paragraph: which step overran, what you'd cut next time, and one thing you forgot that the checklist in §11 would have caught.

## Rubric (per run, /30)
| Criterion | 0 | 3 | 5 |
|---|---|---|---|
| Scope written before design | none | partial | three lists + restatement |
| Implied entities found | 0 | 1 | 2+ with justification |
| Class diagram complete by minute 25 | no | partial | yes, with multiplicity |
| Variation axes named as sentences | none | 1 | 2+, and one deliberately left concrete |
| Edge cases from the checklist | <3 | 3–5 | 6+ across categories |
| Compiling demo by minute 55 | no | partial | happy path runs |

**24+/30 on run 3** → Module 11. If run 3 scores lower than run 1, you're designing more but finishing less: cut the diagram to the six most important boxes.

## Final self-assessment
After all three runs, answer in writing:
1. Which DESIGN step consistently overran, and what will you time-box harder?
2. Which edge-case category do you keep forgetting?
3. Did you ever add an abstraction you couldn't justify? Which one, and why did it feel necessary at the time?

Send me any run's `RunN.md` + `RunN.swift` and I'll review it as an interviewer would, step by step.
