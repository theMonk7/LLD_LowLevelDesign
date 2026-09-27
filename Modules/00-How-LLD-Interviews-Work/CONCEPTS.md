# Module 00 — Concepts: How to Think About Design at All

> Read this before the README. No code, no syntax. This is the shape of the thing you're learning.

---

## 1. The core mental model: design is about *change*, not correctness

Beginners think the job is "make it work". It isn't — a script makes it work.

**Design is the practice of deciding where future change will hurt, and moving the pain somewhere cheap.**

Every program has two costs:
- The cost of writing it once.
- The cost of changing it, forever.

The second cost dominates. A feature written in a day gets modified for five years. So the question that runs underneath every design decision is not *"is this correct?"* but:

> **"When the requirement changes, how many places do I have to touch, and how likely am I to miss one?"**

Hold that sentence. Everything in this course — SOLID, patterns, layering, dependency injection — is a technique for answering it better.

### The intuition pump
Think of your codebase as a **city**, not a machine.

A machine is designed once and assembled. A city is never finished: roads get widened, buildings get demolished, new districts appear. A good city plan doesn't try to predict which buildings will exist in 2050 — it lays out **streets and utilities** so that whatever gets built can connect.

Good design is the same: you don't predict the features. You lay out the boundaries so tomorrow's feature has an obvious place to live.

---

## 2. What "low level" actually means

Two words that confuse everyone:

**High level design (HLD)** = the *city map*. Which districts exist (services), how traffic flows between them (APIs, queues), where the water comes from (databases). Question: *will this hold a million people?*

**Low level design (LLD)** = the *building plan*. Inside one district: rooms, doors, load-bearing walls, plumbing. Question: *can we renovate this without the roof falling in?*

And **DSA** is the *materials science*: is this beam strong enough, is this algorithm fast enough.

You will be asked all three at different stages of an interview loop. They are different skills. LLD is the one where a single class diagram earns or loses the offer, because it's where the interviewer can see how you *think about responsibility*.

---

## 3. The single most important habit: name the thing that varies

Here is the whole course in one sentence, stated early so you can watch it recur:

> **Find what changes, separate it from what doesn't, and put a name on the boundary between them.**

Everything else is technique.

- SOLID's Open/Closed Principle: *put the varying thing behind a boundary so you never edit the stable thing.*
- Strategy pattern: *the varying thing is an algorithm.*
- Factory pattern: *the varying thing is which type gets created.*
- Decorator: *the varying thing is which optional behaviours are stacked.*
- Dependency injection: *the varying thing is which implementation you got.*

When you read a requirement, you should feel yourself reaching for the sentence:

> "The ______ varies by ______."

If you can't fill it in, you don't yet need an abstraction. That's not a failure — that's the correct finding, and saying it out loud is worth more than inventing one.

---

## 4. How an interviewer actually watches you

They are not checking whether you memorised 23 patterns. They are watching for four behaviours, in this order of weight:

**1. Do you bound the problem before solving it?**
An unbounded problem has no correct answer. Candidates who start drawing classes at minute two are solving a problem nobody stated. Candidates who spend six minutes turning a vague prompt into a written paragraph, with explicit exclusions, have already differentiated themselves — before designing anything.

**2. Do responsibilities land in sensible places?**
The interviewer reads your class names and asks themselves: *"if the tax rule changes, which box do I open?"* If the answer is obvious, you're designing. If the answer is "the big one in the middle", you're transcribing.

**3. Does the design survive a new requirement?**
This is why every LLD interview ends with "now add X". They're measuring blast radius. One file is a pass. Eight files is a fail, however elegant the original.

**4. Can you hear your own reasoning?**
Design is a communication skill wearing an engineering costume. A silent designer is indistinguishable from a stuck one.

---

## 5. The two ways to fail, and why they're symmetrical

**Under-design**: one class, 400 lines, a `switch` that grows forever. Fails because change is expensive.

**Over-design**: nine patterns, fourteen protocols, three factories for a game of noughts and crosses. Fails because *understanding* is expensive — and understanding is what change costs.

Notice they fail for the same underlying reason: **both make future change harder.** Under-design makes it risky; over-design makes it incomprehensible.

So the target isn't "as much structure as possible". It's:

> **The least structure that makes the expected changes cheap.**

The word *expected* is load-bearing. Structure that serves a change nobody will request is pure cost. This is why "what's likely to change?" is the highest-value question you can ask an interviewer — it tells you where to spend your structure budget.

---

## 6. A useful frame: every design decision is a bet

When you introduce a protocol, you are betting that a second implementation will appear. That bet has a price (indirection, an extra file, one more concept for a reader) and a payoff (a future change costs one new file instead of an edit).

- Bet and win: the feature lands easily, you look prescient.
- Bet and lose: you carry dead abstraction forever.
- Don't bet, and the change comes: you refactor — which, for a well-named concrete type, is usually twenty minutes.

That last line is why the default should be **concrete until proven otherwise**. The cost of a late extraction is small and *known*. The cost of a wrong abstraction is large and *hidden*, because three other people will have built on it.

Say it in interviews: *"I'd keep this concrete for now; when the second case appears, extracting it is a small refactor."* That's not laziness — it's correctly priced risk.

---

## 7. How to build design intuition (the actual training method)

Intuition is compressed experience. You can compress it deliberately:

**a) Read requirements as a list of nouns and verbs, not as prose.**
Your brain wants to imagine screens. Fight it. Underline the nouns — those are candidate types. Underline the verbs — those are candidate methods. Then ask which noun *owns* each verb.

**b) For every rule, ask "who knows this?"**
A rule should live with the data it constrains. "A member can borrow three books" is a fact about a member (or a lending policy), not a fact about the screen that shows a button.

**c) For every type, ask "what would make me edit this file?"**
If the honest answer has an "and" in it, you've found a split.

**d) After every design, ask "now add X" yourself.**
Pick a plausible next feature and trace it. Count the files. This is the same measurement the interviewer will take; take it first.

**e) Reread your own code from six months ago.**
Nothing teaches design like discovering what past-you made expensive.

---

## 8. Vocabulary you're about to acquire, and why it matters

You will spend the next fifteen modules learning terms: encapsulation, coupling, cohesion, Liskov, Strategy, Decorator, idempotency.

It's tempting to treat these as jargon to memorise. They're better understood as **compression**. Each term is a whole paragraph of reasoning packed into one word, so that two engineers can discuss a tradeoff in a sentence instead of an afternoon.

> "I'd put pricing behind a protocol — that's Strategy — because the rule varies per city and I want to add a city without touching the fare calculator."

That sentence carries a problem, a solution, a justification and a predicted benefit. Without the vocabulary it takes five minutes and stays vague.

So learn the words *with their reasons attached*. A pattern name recited without its motivating pressure is worse than useless in an interview: it signals memorisation, which is exactly what the interviewer is trying to see past.

---

## 9. What to expect from the rest of this course

- **Modules 01–03** build the raw material: what a good type is, what a good boundary is, and how to tell.
- **Module 04** gives you the notation to show it to someone else.
- **Modules 05–08** give you the catalogue — and, more importantly, the judgment about when *not* to open it.
- **Module 09** handles the question every design eventually meets: what happens when two things happen at once.
- **Modules 10–13** are practice, from small to large, until the method is automatic.
- **Module 14** connects everything to the iOS code you write for a living.
- **Module 15** turns knowledge into performance.

The through-line, in every module: **find what varies, name the boundary, and pay only for the structure you'll use.**

---

## ✅ Concept checkpoint
Answer these in your own words, out loud:
1. Why is "will this survive change?" a better design question than "is this correct?"
2. Explain the difference between HLD, LLD and DSA using the city metaphor.
3. Why do under-design and over-design fail for the same reason?
4. What is the *price* of introducing a protocol, and what's the payoff?
5. Why is "I'd keep this concrete for now" sometimes the strongest answer available?

Then read the module `README.md`.
