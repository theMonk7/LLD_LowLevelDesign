# Module 01 Project — Library Catalog Domain Model

**Time:** 2–3 hours. **Start from an empty file.** No patterns yet (Modules 05–07 add those) — this project is graded purely on type boundaries, semantics, encapsulation and coupling.

---

## Brief (deliberately slightly vague — clarify it yourself first)

> Model the domain of a small library: books, copies, members, borrowing and returning.

Before writing code, write at the top of your file, as comments:
- 5 clarification questions you'd ask (Module 00 §4)
- your **in scope / out of scope / assumptions** lists

You are graded on this section too. Most candidates skip it; it's the cheapest differentiator you have.

---

## Functional requirements (the scope you must cover)

1. A **Book** is a title (ISBN, title, author, year). The library owns multiple physical **Copies** of a book.
2. A **Member** can borrow up to **3 copies** at a time.
3. Borrowing a copy that is already on loan must fail.
4. Returning a copy makes it available again; returning a copy that isn't on loan must fail.
5. A copy is due **14 days** after borrowing. The system can list a member's **overdue** copies given a "today" date.
6. Search the catalog by author or by title substring (case-insensitive).
7. A copy can be marked **lost**; a lost copy can never be borrowed again.

## Explicitly out of scope
Persistence, UI, networking, fines/payments, reservations/holds, concurrency, authentication.

## Non-functional
- Pure Swift, no dependencies, compiles with `swift build`.
- Deterministic time: **inject `Date` as a parameter or a clock protocol** — never call `Date()` inside domain logic.
- Every rule must be enforced by a type, not by the caller.

---

## Deliverables

1. `LibraryCatalog.swift` — the model.
2. `main`/`demo()` that runs the 8 acceptance scenarios below and prints results.
3. Your own test file (6+ tests). Writing the tests is part of the project.
4. A short comment block: which types are `struct`, which are `class`, and **why** for each.

---

## Acceptance scenarios (your demo must show all 8)

| # | Scenario | Expected |
|---|---|---|
| 1 | Member borrows an available copy | succeeds; copy unavailable; member has 1 loan |
| 2 | Another member borrows the same copy | fails: already on loan |
| 3 | Member borrows a 4th copy | fails: limit reached |
| 4 | Member returns a copy, another borrows it | both succeed |
| 5 | Return a copy that isn't on loan | fails |
| 6 | Query overdue as of day 20 for a loan made on day 1 | that copy is overdue |
| 7 | Query overdue as of day 10 for the same loan | empty |
| 8 | Mark a copy lost, then borrow it | fails |

---

## Design hints (read only if stuck for >20 minutes)

<details>
<summary>Hint 1 — entity vs value</summary>

Which of these has **identity** (two references must see the same state) and which is just data compared by contents?
`Book` / `Copy` / `Member` / `Loan` / `ISBN` / `DueDate`.
Identity → `class`. Data → `struct`.
</details>

<details>
<summary>Hint 2 — where do the rules live?</summary>

"At most 3 loans" — whose invariant is it? If the answer is "whoever calls borrow()", you have an anemic model. Put the rule inside the type that owns the data it constrains.
</details>

<details>
<summary>Hint 3 — copy state</summary>

`isAvailable: Bool` + `isLost: Bool` lets you represent the impossible state *lost AND on loan*. An `enum CopyState { case available, onLoan(memberID: String, due: Date), lost }` makes that unrepresentable. Making illegal states unrepresentable is the strongest form of encapsulation Swift offers.
</details>

<details>
<summary>Hint 4 — time</summary>

`func overdueCopies(asOf now: Date) -> [Copy]`. Injecting the date is the same idea as injecting the `PriceFeed` in E7 — it turns an untestable dependency into a parameter.
</details>

---

## Self-grading rubric (score yourself honestly, /40)

| Criterion | 0 | 3 | 5 |
|---|---|---|---|
| **Clarification & scope** written first | absent | vague | specific, with assumptions |
| **struct/class choice** justified | unjustified | mostly right | right + explained by identity |
| **Encapsulation** | public mutable state | some `private(set)` | no way to reach an invalid state |
| **Invariants in the type** | enforced by caller | mixed | fully inside the domain types |
| **Illegal states unrepresentable** | booleans everywhere | partial | enum state machine |
| **Coupling** | `Date()` / globals inside logic | some injection | all dependencies injected |
| **Cohesion** | one `LibraryManager` does everything | some split | each type has one reason to change |
| **Tests** | none | happy path | happy path + every failure case |

**32+/40** → move to Module 02.
**Below 24** → re-read README §2, §3, §9, then redo the project from scratch. Redoing it is faster than you expect and worth more than reading.

---

## Extension questions (answer in writing — this is what interviewers actually ask next)

1. Add **reservations**: a member reserves a book; when a copy is returned, the first reserver gets it. Which existing type changes? If the answer is "several", your boundaries were wrong.
2. The limit becomes **3 for regular members, 10 for staff**. How do you do this *without* an `if memberType == .staff` inside `borrow()`? (This is Strategy, Module 07 — try it anyway.)
3. Two members borrow the last copy at the same instant. Where exactly is the race? (Module 09.)
4. The library wants an **audit log** of every borrow and return without touching the borrowing code. What's your approach? (Observer/Decorator, Modules 06–07.)

When you're done, ask me to review your `LibraryCatalog.swift` against this rubric.
