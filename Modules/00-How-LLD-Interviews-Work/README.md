# Module 00 — How LLD Interviews Actually Work

> **Start with [`CONCEPTS.md`](CONCEPTS.md).** It carries the mental models, the intuition and the
> *why* behind everything below — no code. This file is the detailed reference you read second,
> once the ideas have a shape to attach to.

> Read this once now for orientation. You will re-read it in Module 10, where each step is expanded with drills.

---

## 1. What "Low Level Design" means

**HLD (High Level Design)** answers: *how many services, which database, how do boxes talk, how does it scale to 10M users?* Output: boxes and arrows.

**LLD (Low Level Design)** answers: *inside one service or one app, what are the classes, what does each one own, how do they collaborate, and is the design open to change?* Output: a class diagram and working code.

DSA answers *"what algorithm?"*. LLD answers *"what abstraction?"*. Interviewers switch from "is it correct" to **"is it correct, and will it survive the next six feature requests"**.

### What you are actually graded on

| Weight | Signal | What it looks like |
|---|---|---|
| 25% | **Requirement clarification** | You asked before you coded. You wrote down scope and explicitly deferred things. |
| 25% | **Class design** | Right responsibilities, right boundaries, nothing is a God Object, names match the domain. |
| 20% | **Extensibility** | When the interviewer says "now add X", you change ~one file, not ten. |
| 15% | **Correct use of patterns** | You used a pattern because something varied — not because you memorised it. |
| 10% | **Code quality** | Compiles, runs, readable, no dead abstractions. |
| 5% | **Communication** | You narrated tradeoffs instead of going silent for 10 minutes. |

Two failure modes, equally fatal:
- **Under-design**: one 400-line class with a giant `switch`. Fails extensibility.
- **Over-design**: 9 patterns, 14 protocols, 3 factories for a Tic-Tac-Toe board. Fails judgment.

---

## 2. Round formats you will face

| Format | Duration | Deliverable | Emphasis |
|---|---|---|---|
| **Design discussion** | 45–60 min | Class diagram + verbal walkthrough, maybe skeleton code | Abstractions, tradeoffs |
| **Machine coding** | 90–120 min | Compiling, runnable program with a `main` demo | Working code + design, tests if time |
| **Code + extend** | 60 min | Code a core, then extend live to a new requirement | Extensibility under pressure |
| **Refactor** | 45 min | Given bad code, improve it | SOLID fluency (Module 02) |

iOS-specific variants add: "design this as a reusable framework", "how would you make this testable", "where do you put this in MVVM?" — Module 14.

---

## 3. The DESIGN framework

Use this exact order, every single time, out loud.

```
D — Discover requirements      (5–8 min)
E — Entities & actors          (5 min)
S — Structure: classes + UML   (10 min)
I — Interfaces & interactions  (5 min)
G — Gaps: patterns, edge cases (5 min)
N — Nail it down: code         (rest)
```

### D — Discover requirements
Never start with classes. Spend 5–8 minutes converting a vague prompt into a bounded problem. Say out loud:
> "Let me clarify scope first, then I'll list what I'm explicitly leaving out."

Produce three lists on the board:
- **In scope** (3–6 functional requirements)
- **Out of scope** (things you deliberately defer: payments, auth, persistence, UI)
- **Non-functional** (concurrency, extensibility axes, scale bounds)

### E — Entities & actors
- **Actors**: who/what initiates action (Customer, Admin, Sensor, Scheduler).
- **Use cases**: one line per actor action ("Customer parks a vehicle").
- **Entities**: extract nouns from the requirements. Nouns → candidate classes. Verbs → candidate methods.
- Kill the fake nouns. "System", "Manager", "Data", "Info" are usually not entities.

### S — Structure
Draw the class diagram: each class with its key fields and 2–4 key methods, plus relationships (Module 04). Ask for each class: *"what single reason would make me change this?"* (SRP, Module 02).

### I — Interfaces & interactions
Define the public API of each class, then walk one use case end-to-end as a sequence: who calls whom, in what order, what comes back. This catches missing methods instantly.

### G — Gaps
Now — and only now — ask **"what varies?"**:
- Varies by *algorithm* → Strategy
- Varies by *object type created* → Factory
- Varies by *number of optional config knobs* → Builder
- Varies by *behaviour over the object's lifetime* → State
- Varies by *who must be notified* → Observer
- Varies by *layers of optional behaviour* → Decorator
- Varies by *who handles a request* → Chain of Responsibility

Then edge cases: empty, full, concurrent, duplicate, failure/rollback, invalid input.

### N — Nail it down
Code the core path first: entities → core service → one working demo in `main`. Stub the periphery and say you're stubbing it. A running 70% beats a beautiful 100% that never compiles.

---

## 4. The clarification question bank (short version)

Ask 6–10 of these, chosen for the problem. Full 40-question bank in Module 10.

**Scope**
1. Single instance/app, or multi-tenant?
2. Is persistence in scope or can state live in memory?
3. Do I need authentication/authorisation?
4. Is there a UI, or is a clean API surface enough?

**Domain**
5. Who are the actors, and what can each do?
6. What are the entity lifecycles (created → … → terminal state)?
7. Which rules are fixed vs configurable by an admin?

**Behaviour & variation**
8. What's likely to change later? (This is the highest-value question you can ask.)
9. Are there multiple strategies for <pricing / allocation / matching>?
10. Does anything need to be notified when state changes?

**Scale & concurrency**
11. Single-threaded or concurrent access?
12. Rough numbers — 10 items or 10 million? (Changes data structure choice.)
13. Any latency requirement on the hot path?

**Edge cases**
14. What happens when the resource is exhausted?
15. Can an operation be undone or refunded?
16. What's idempotent and what isn't?

---

## 5. Time-boxing a 60-minute round

| Minute | Activity |
|---|---|
| 0–8 | D: clarify, write scope/out-of-scope/NFRs |
| 8–13 | E: actors, use cases, entity nouns |
| 13–25 | S: class diagram on the board |
| 25–30 | I: public APIs + one sequence walkthrough |
| 30–35 | G: patterns where something varies, edge cases |
| 35–55 | N: code the core |
| 55–60 | Demo + "here's what I'd add with more time" |

If you are still clarifying at minute 15, you will not finish. If you started coding at minute 3, you will design the wrong thing.

---

## 6. Phrases that earn points

- "Before I design, let me confirm scope — I'll assume X and Y are out of scope, tell me if that's wrong."
- "I'm making this a protocol because I expect pricing rules to change; if they never change, a plain function is enough."
- "That's a Strategy here rather than a subclass, because the algorithm varies independently of the vehicle type."
- "I'll keep this mutable state behind an actor so the booking path is safe under concurrency."
- "I'm deliberately *not* adding a factory here — there's exactly one implementation, so it'd be indirection without payoff."
- "Let me trace the 'user parks and exits' flow through these classes to check I haven't missed a method."

## 7. Phrases that lose points

- Silence longer than 30 seconds.
- "I'll use Singleton for the manager" with no thread-safety or testability discussion.
- Starting code before naming a single entity.
- Adding an interface with exactly one implementation and no stated variation axis.
- "I'd need to look that up" about SOLID.

---

## ✅ Module 00 checkpoint

Without looking back, write down from memory:
1. The six letters of DESIGN and what each one produces.
2. Five clarification questions you'd ask for "Design a Vending Machine".
3. Two ways a candidate can fail a 60-minute LLD round.

Then start Module 01.
