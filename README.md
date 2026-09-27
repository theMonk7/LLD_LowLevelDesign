# LLD Mastery Track — Swift Edition

A sequential, zero-to-pro Low Level Design curriculum for an iOS/Swift engineer.
Every concept, every example, every solution is in **Swift**. Everything compiles and is verified by `swift test`.

Topic coverage is a strict superset of the [Krucible LLD sheet](https://krucible.netlify.app/) (OOP → SOLID → Principles → UML → 22 GoF patterns → 20 practice problems), plus concurrency, pattern-selection heuristics, the interview framework, and an iOS-architecture module the sheet does not have.

---

## How this repo works

```
LLD/
├── README.md                ← you are here (master plan)
├── PROGRESS.md              ← your tracker; tick boxes as you go
├── Package.swift            ← one Swift package, one target pair per module
└── Modules/
    └── NN-Module-Name/
        ├── CONCEPTS.md      ← MENTAL MODELS. Read this FIRST. Almost no code.
        ├── README.md        ← THEORY + reference. Read second.
        ├── EXERCISES.md     ← problems to solve yourself
        ├── SOLUTIONS.md     ← commentary; read ONLY after attempting
        ├── PROJECT.md       ← the module's mini-project (the real test)
        ├── Code/            ← worked examples + exercise stubs (compiled)
        ├── Tests/           ← XCTest suite that grades your answers
        └── Solutions/       ← reference Swift, NOT compiled into your build
```

Modules 04 (UML) and 15 (mocks) are documentation-only — their deliverables are diagrams and recordings, so they have no `Code/` or `Tests/`.
Modules 11–13 also carry `Solutions/Solved.swift`: the fully worked problems whose walkthroughs are in that module's `README.md`.

### The study loop for every module

| Step | What you do | Time |
|---|---|---|
| 0 | Read `CONCEPTS.md` — mental models, intuition, how to think. No code. | 25–40 min |
| 1 | Read `README.md` — the detailed reference, with Swift | 60–90 min |
| 2 | Fill the stubs in `Code/Exercises.swift` | 60–120 min |
| 3 | `swift test --filter MNN` → green = correct | 10 min |
| 4 | Compare with `SOLUTIONS.md`, note *why* yours differed | 20 min |
| 5 | Build `PROJECT.md` from a blank file, no peeking | 2–4 h |
| 6 | Self-grade against the project rubric, tick `PROGRESS.md` | 15 min |

### Commands

```bash
swift build                    # compile everything
swift test                     # run all module graders
swift test --filter M01        # grade only module 1
swift run M01Demo              # run a module's demo executable (where present)
```

**Why two files per module.** `CONCEPTS.md` explains *why the idea exists* and how to reason with it — read it like an essay, with no editor open. `README.md` is the detailed reference: definitions, Swift, diagrams, tables, smells. Reading the reference first works, but the ideas have nothing to attach to, so they fall out again. Reading concepts first is slower on day one and much faster by module five.

**The Swift files are teaching material too.** Every `Solutions/*.swift` carries a "how to read this file" header and inline `// WHY` blocks explaining what a line is buying, what breaks with the obvious alternative, and which decision was a product question rather than a coding one. Every `Code/Exercises.swift` opens with the questions to ask yourself *before* typing.

**Rule: never open `SOLUTIONS.md` before your test run is red-then-green on your own code.** The value is in the struggle, not the reading.

---

## The 16 modules

### Phase 1 — Foundations (weeks 1–2)

**Module 00 — How LLD Interviews Actually Work**
The 6-step DESIGN framework, the requirement-clarification question bank, how to scope in 45 minutes, machine-coding round vs design-discussion round, what interviewers actually grade. *Read early for orientation; re-read at Module 10 for depth.*

**Module 01 — OOP Fundamentals in Swift**
Class vs object; encapsulation, abstraction, inheritance, polymorphism; `struct` vs `class` (value vs reference semantics — the Swift-specific trap); protocols as Swift's interfaces; protocol + extension as Swift's "abstract class"; `final`, `open`, access control; composition vs inheritance; coupling vs cohesion; protocol-oriented programming.
🛠 Project: **Library Catalog domain model**

**Module 02 — SOLID, Deeply**
Each letter gets: definition, smell that signals violation, Swift violation example, Swift fix, how it shows up in UIKit/SwiftUI code you already write, and how interviewers probe it. Includes the LSP contract rules (pre/postconditions, invariants, history) that most people get wrong.
🛠 Project: **Refactor a deliberately-rotten `ReportGenerator` to SOLID**

**Module 03 — The Other Principles**
DRY, KISS, YAGNI, Law of Demeter, Composition over Inheritance, Encapsulate What Varies, Program to an Interface, Tell-Don't-Ask, Hollywood Principle, Separation of Concerns, GRASP responsibilities (Information Expert, Creator, Controller, Low Coupling, High Cohesion, Pure Fabrication).
🛠 Project: **Principle audit of a 300-line Swift file**

**Module 04 — UML for LLD Interviews**
Class diagram (the only one you must be fluent in), sequence, use case, activity, state machine, component. Multiplicity, association vs aggregation vs composition, dependency vs realization. Written in Mermaid so it renders in GitHub/VS Code and you can draw it on a whiteboard in 2 minutes.
🛠 Project: **Full UML pack for a Food Delivery system**

### Phase 2 — Patterns (weeks 3–6)

**Module 05 — Creational Patterns**
Singleton (+ thread safety, + why it's usually wrong), Factory Method, Abstract Factory, Builder, Prototype, Object Pool, Dependency Injection as the anti-Singleton. Each: intent → problem → Swift solution → UML → real iOS usage (`URLSession.shared`, `UIStoryboard`, `NSCopying`, SwiftUI `ViewBuilder`) → pitfalls → interview probes.
🛠 Project: **Pluggable Notification Service (Email/SMS/Push) with Builder config**

**Module 06 — Structural Patterns**
Adapter, Bridge, Composite, Decorator, Facade, Flyweight, Proxy. Same template. Includes Decorator-vs-Proxy-vs-Adapter disambiguation, which is the #1 confusion point.
🛠 Project: **Coffee shop pricing engine (Decorator) + legacy payment SDK Adapter**

**Module 07 — Behavioral Patterns**
Chain of Responsibility, Command, Iterator, Mediator, Memento, Observer, State, Strategy, Template Method, Visitor, Null Object. Plus Swift-native equivalents (Combine/`AsyncSequence` = Observer, `Sequence`/`IteratorProtocol` = Iterator, closures = Strategy/Command) and when the native form beats the classic form.
🛠 Project: **Text editor with undo/redo (Command + Memento) and state-driven toolbar (State)**

**Module 08 — Choosing the Right Pattern**
Decision trees, "what varies?" analysis, the symptom→pattern lookup table, pattern combinations that appear together, over-engineering smells, anti-patterns (God Object, Anemic Domain Model, Singleton-itis, pattern fever). 30 short "which pattern and why?" drills.
🛠 Project: **Pattern-selection written exam (30 scenarios)**

**Module 09 — Concurrency for LLD**
Why every real LLD problem (parking lot, elevator, rate limiter, booking) has a concurrency question hiding in it. Race conditions, critical sections, `NSLock`/`DispatchQueue`/`actor`, Swift 6 strict concurrency & `Sendable`, thread-safe Singleton, producer-consumer, optimistic vs pessimistic locking for seat booking, idempotency.
🛠 Project: **Thread-safe seat-booking core that survives 10k concurrent bookings**

### Phase 3 — Problem Solving (weeks 7–11)

**Module 10 — The LLD Problem-Solving Framework**
The full method, deep: requirement gathering → actors & use cases → noun/verb extraction → core entities → relationships → class diagram → API surface → pattern injection → edge cases → extensibility questions → code. Includes a printable 40-question clarification bank and time-boxing for 45/60/90-minute rounds.
🛠 Project: **Apply the framework end-to-end to Vending Machine, on the clock**

**Module 11 — Easy Problems (7 solved + 5 solo)**
Solved with full walkthroughs and code: Tic-Tac-Toe, Snake & Ladder, Browser History, Min Stack, LRU Cache, HashMap, Trie. Solo, with graders: Deck of Cards, Connect Four, Ring Buffer, Autocomplete, Leaderboard. (Vending and Coffee machines are built in Module 10.)
🛠 Project: **Blackjack, end to end**

**Module 12 — Medium Problems (8 solved + 5 solo)**
Solved: Parking Lot, ATM, Splitwise, Rate Limiter (token bucket), Underground System, Logging Framework, Library Management, Hotel Management. Solo: LFU Cache, Coupon Engine, In-Memory File System, Job Scheduler with dependencies, Meeting Rooms.
🛠 Project: **Ride-hailing core (Uber-lite)**

**Module 13 — Hard Problems (5 solved + 2 design-only + 4 solo)**
Solved with code: Elevator System, Chess, BookMyShow, Food Delivery lifecycle, Inventory with reservations. Design-only walkthroughs: Cab Booking, Distributed Job Scheduler. Solo: Retrying Job Queue, Topic Broker, Consistent Hash Ring, Elevator LOOK Scheduler.
🛠 Project: **Multiplayer chess server core**

### Phase 4 — Applied & Interview (weeks 12–13)

**Module 14 — LLD for iOS Engineers**
Where these patterns live in your day job: MVC → MVVM → VIPER → Clean Architecture compared honestly; Coordinator pattern; Repository + DTO/Domain/Entity mapping; DI containers in Swift; designing a networking layer, an image cache, an analytics SDK, a feature-flag system, an offline-sync engine. This is what Apple/Uber/Swiggy iOS interviews actually ask.
🛠 Project: **Design an image-loading library (SDWebImage clone), full LLD**

**Module 15 — Mock Interviews & Retention**
8 timed mocks with interviewer scripts and grading rubrics, common failure modes, how to recover from a stuck moment, spaced-repetition schedule, one-page cheat sheets for the night before.

---

## Suggested schedule (13 weeks, ~8 h/week)

| Week | Modules |
|---|---|
| 1 | 00, 01 |
| 2 | 02, 03 |
| 3 | 04, 05 |
| 4 | 05 (cont.), 06 |
| 5 | 06 (cont.), 07 |
| 6 | 07 (cont.), 08 |
| 7 | 09, 10 |
| 8 | 11 |
| 9 | 12 |
| 10 | 12 (cont.), 13 |
| 11 | 13 (cont.) |
| 12 | 14 |
| 13 | 15 |

Compressible to 7 weeks at 16 h/week. Do not skip Modules 01–03; every later module leans on them.

---

## What's in here

| | Count |
|---|---|
| Modules | 16 |
| Concept files (mental models, no code) | 16 |
| Graded exercise suites (`swift test`) | 13 |
| Individual graded assertions | 400+ |
| Fully solved LLD problems with walkthroughs | 20 |
| Solo problems with graders | 14 |
| Rubric-graded module projects | 14 |
| Design patterns covered in Swift | 25 (22 GoF + DI, Null Object, Coordinator) |
| Timed mock interviews with scripts | 8 |

Every Swift file carries reasoning comments, and every one compiles under **Swift 6 strict concurrency**, and every reference solution has been run against its own grader.

## Prerequisites

Swift 6.x toolchain (you have 6.2.3), Xcode or VS Code + Swift extension. No third-party dependencies.

## Reference material (optional, secondary to this repo)

- Refactoring Guru — Design Patterns (language-agnostic diagrams)
- *Head First Design Patterns* — best intuition-building book
- GoF *Design Patterns* — reference, not a reader
- *Clean Code* / *Clean Architecture*, Robert Martin — for Modules 02–03 and 14
