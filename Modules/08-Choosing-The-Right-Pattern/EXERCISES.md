# Module 08 — Exercises: 30 Selection Drills

For each drill: (1) write the sentence *"The ___ varies by ___"*, (2) name the smallest thing that works, (3) then fill the case in [`Code/Exercises.swift`](Code/Exercises.swift).

Run `swift test --filter M08`. The grader requires **30/30** — this is recall, and partial recall fails interviews.

Several answers are `.noPatternNeeded`. Resisting a pattern is the skill being tested.

| # | Scenario |
|---|---|
| 01 | Shipping cost is computed differently for each carrier, and carriers keep being added. |
| 02 | An `Order` behaves differently in `placed`, `paid`, `shipped`, `cancelled` — and *every* method starts with a check on the status. |
| 03 | Three separate dashboards must refresh whenever a stock price changes. The price source shouldn't know who's watching. |
| 04 | A drawing app must support undo of every action, including "apply filter". |
| 05 | A vendor SDK exposes `processTxn(amtRupees:refId:)`, but the whole app calls `pay(amountInPaise:orderID:)`. |
| 06 | You must add logging and retry around an existing repository, without editing it, and be able to turn each on independently. |
| 07 | A type needs 8 initialiser parameters, 6 with sensible defaults, all known at the call site. |
| 08 | Same 8 parameters, but assembled across three functions, and three rules span multiple fields and can only be checked at the end. |
| 09 | One immutable configuration object, loaded at launch, read by many components. |
| 10 | A restaurant menu contains dishes and sub-menus, which contain dishes and sub-menus. You must price the whole thing. |
| 11 | Expenses are approved by a team lead up to 10k, a manager up to 100k, a director up to 1M. |
| 12 | A map shows 200,000 pins drawn from 12 distinct icons. |
| 13 | Document reads must be denied unless the current user is an admin. The document API must stay unchanged. |
| 14 | Ten form controls enable, disable and clear each other as the user fills the form. |
| 15 | An AST has a fixed set of 9 node types; you keep being asked for new operations over it (pretty-print, type-check, emit JS). |
| 16 | The analytics dependency is optional — most apps run without it, and no call site should write `if let`. |
| 17 | Database connections take 200 ms to open and are safe to reuse. Traffic is bursty. |
| 18 | You need to sort users by name in one screen and by age in another. |
| 19 | A board game must snapshot its entire state before each turn so a player can take a move back. |
| 20 | Dark and light widget sets exist; a dark button must never appear next to a light checkbox. |
| 21 | `WeatherService` creates its own `URLSession` inside `init`, and you can't test it. |
| 22 | The same tree must be walked in preorder for rendering and level order for search. |
| 23 | Checkout is always validate → price → tax → receipt; only the tax step differs by country. |
| 24 | Converting a video always means decode, extract audio, transcode, mux — and every caller writes those four lines. |
| 25 | 5 shapes × 4 renderers would mean 20 classes. |
| 26 | A configured document template is built once at launch and copied hundreds of times per session. |
| 27 | The parser to use is chosen from the file extension; plugins may add extensions at runtime. |
| 28 | Convert Celsius to Fahrenheit, used in two screens. |
| 29 | Every HTTP request must pass through auth, then rate limiting, then logging — and each stage may reject it. |
| 30 | An `EmailAddress` type must be impossible to construct in an invalid form. |

## After the drills — written answers (not graded, but do them)
1. For drills 07 and 08, explain what changed between them that flipped the answer.
2. For drill 18, why isn't this Strategy? Give the general rule you used.
3. For drill 15, argue the opposite answer (enum + exhaustive switch) as strongly as you can.
4. For drills 11 and 29, the same pattern has two different flavours. Name them.
5. Pick three drills where you were wrong or unsure and write the variation sentence for each.
