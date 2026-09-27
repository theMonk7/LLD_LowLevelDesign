# Module 15 — Eight Mock Interviews

Each mock has a prompt, a schedule of interviewer interventions, and the signals being scored. **Read only the prompt before you start.** Have the interventions delivered by a partner, or set alarms and read them yourself when they fire.

Record every one. Grade from the recording using the sheet in `README.md` §2.

---

## Mock 1 — Design a Vending Machine (45 min, warm-up)

**Prompt:** "Design a vending machine."

| Minute | Interviewer says |
|---|---|
| 0 | (nothing — wait and see if you clarify) |
| 12 | "What happens if the machine can't make exact change?" |
| 25 | "Now the operator wants happy-hour pricing between 4 and 6 pm." |
| 35 | "Two people put coins in at the same time on a machine with two slots." |
| 42 | "What would you add with another hour?" |

**Scored for:** whether you clarified unprompted; failure atomicity on the change problem; whether happy-hour pricing was a new file or an edit; whether you named check-then-act without help.

---

## Mock 2 — Design a Parking Lot (45 min)

**Prompt:** "Design a parking lot for a shopping mall."

| Minute | Interviewer says |
|---|---|
| 10 | "Can a motorcycle park in a truck spot? Should it?" |
| 20 | "We're adding electric-vehicle spots with charging that costs extra." |
| 30 | "The lot has 10,000 spots and the display board must be real-time." |
| 38 | "How would you test the fee calculation?" |

**Scored for:** best-fit vs first-fit reasoning; whether EV support is a new spot type, a new pricing strategy, or both; whether you recognise the O(n) scan and propose free-lists; whether "inject the clock" comes out immediately.

---

## Mock 3 — Design an Elevator System (60 min)

**Prompt:** "Design the control system for a building with four elevators and twenty floors."

| Minute | Interviewer says |
|---|---|
| 8 | "What's the difference between a request from inside a car and one from a floor?" |
| 20 | "Which car do you send, and why?" |
| 32 | "Now implement a different scheduling algorithm." |
| 45 | "A car reaches capacity. What changes?" |
| 55 | "Where's the shared mutable state?" |

**Scored for:** separating car mechanics from dispatch policy; whether the second algorithm is a new conformer or an edit; whether capacity is handled without breaking existing drop-offs; naming the stop-set race.

---

## Mock 4 — Design Splitwise (45 min)

**Prompt:** "Design an app where friends split shared expenses."

| Minute | Interviewer says |
|---|---|
| 8 | "How do you split — is it always equal?" |
| 18 | "Someone edits an expense from last month. What happens to the balances?" |
| 28 | "Show me who owes whom, minimising the number of payments." |
| 38 | "Two currencies in one group." |

**Scored for:** whether balances are derived rather than stored (the edit question is a trap and it's the whole interview); split types as an enum with associated values; greedy settlement with the honest complexity caveat; whether currency conversion time is questioned.

---

## Mock 5 — Design an Image-Loading Library (60 min, iOS-specific)

**Prompt:** "Design a library that loads and caches images for a scrolling feed."

| Minute | Interviewer says |
|---|---|
| 10 | "Sixty cells all request the same avatar. What happens?" |
| 22 | "The user scrolls past before the download finishes." |
| 33 | "Memory warning." |
| 42 | "How do you test any of this?" |
| 52 | "The same image is needed at two different sizes." |

**Scored for:** request coalescing with the in-flight task published before suspension; cancellation semantics when several callers wait; cost-based eviction; protocol seams for all three layers; cache keys including the transformation.

---

## Mock 6 — Refactor Round (45 min)

**Prompt:** You're given the `ReportGenerator` from the Module 02 project (or the `CheckoutEngine` from Module 03). "Review this and improve it."

| Minute | Interviewer says |
|---|---|
| 0 | "Take five minutes to read it, then tell me what you see." |
| 15 | "Which of these would you fix first, and why?" |
| 25 | "Do it." |
| 38 | "Add a new output format." |

**Scored for:** naming smells with principles rather than taste; prioritising by risk not by ease; whether the refactor preserves behaviour (did you write a characterisation test?); the new format touching zero existing files.

---

## Mock 7 — Design BookMyShow (60 min)

**Prompt:** "Design seat booking for a cinema chain."

| Minute | Interviewer says |
|---|---|
| 8 | "How long do you hold a seat while the user pays?" |
| 20 | "The user's app crashes after selecting seats." |
| 30 | "Two users tap the same seat at the same instant." |
| 42 | "Payment succeeds but your confirm step fails." |
| 52 | "Recommend the best three adjacent seats." |

**Scored for:** three seat states with a TTL; lazy expiry as the crash answer; reserve-then-pay-outside-the-lock; idempotency for the confirm failure; whether recommendations go into a new type rather than onto `Show`.

---

## Mock 8 — Open-Ended Architecture (60 min, iOS-specific)

**Prompt:** "You're the first engineer on a new shopping app. Thirty screens, three teams, six months. How do you structure it?"

| Minute | Interviewer says |
|---|---|
| 10 | "Why not VIPER?" |
| 20 | "Where does networking live, and how does a screen get data?" |
| 30 | "How do you keep the three teams from blocking each other?" |
| 40 | "A screen needs data from two services and shows a partial state." |
| 50 | "What do you regret about this design in a year?" |

**Scored for:** a named architecture with a stated condition for choosing differently; the dependency rule (domain imports nothing); module boundaries as the team-parallelism answer; state modelled as one enum rather than three booleans; genuine self-criticism on the last question.

---

## After each mock

Write three lines in `PROGRESS.md`:
1. Score out of 50.
2. The one moment that cost the most points.
3. The one sentence you'll say next time instead.
