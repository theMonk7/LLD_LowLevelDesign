# Module 08 — Concepts: Taste

> Read before the README. You now know the catalogue. This module is about the thing that can't be memorised: knowing when *not* to open it.

---

## 1. The mental model: patterns are answers, so find the question first

A pattern is a **named solution to a recurring problem in a context**. Three parts — and people remember only the solution.

That's why pattern-first thinking fails. If you start from "which pattern?", you're searching a list of answers for one that resembles your situation, and you will always find one, because the answers are general. What you *won't* have done is check whether you had the problem.

> **Reverse it: describe the pressure in plain language. The pattern is what that description is called.**

If you can say *"the fee calculation changes per city, and cities are added monthly, so I want to add a city without touching the calculator"* — you have already designed it. Naming it Strategy adds nothing except brevity for the listener.

And if you can't produce that sentence, no pattern applies, because there's no pressure to relieve.

---

## 2. The four questions, in order

**Q1. What varies?**
Fill in: *"The ___ varies by ___."* Both blanks must be concrete. "The behaviour varies by situation" is not an answer; "the discount varies by customer tier" is.

**Q2. Does it vary now, or might it vary later?**
Now, with two or more real cases → build it. Later, hypothetically → don't. A guessed abstraction is usually the wrong shape, and wrong shapes are harder to remove than missing ones are to add.

**Q3. Who should own the variation?**
Usually the type that holds the data the rule needs. When the rule spans several types, invent a type for it rather than forcing it onto one of them.

**Q4. What is the smallest thing that works?**
There is a ladder, and you should always start at the bottom:

> a parameter → a closure → an enum with a switch → a protocol with two conformers → a full pattern

Most real code lives in the first three rungs. Climbing one rung costs a concept the reader must hold; you should be able to say what each rung buys.

---

## 3. The single most useful instinct: open vs closed sets

Nearly every "which mechanism?" question reduces to one property of the domain:

> **Is the set of variants closed, or will it keep growing — possibly by people who don't work here?**

**Closed** — four suits, three coin denominations, two directions, the HTTP methods you support. Model it as an enum and let the compiler check exhaustiveness. Adding a case then produces a *compile error at every place that must change*, which is a stronger guarantee than any protocol gives you.

**Open** — payment providers, discount rules, export formats, plugin types. Model it behind a protocol or a registry so a new variant is a new file.

Getting this wrong is expensive in both directions. Enum for an open set → you edit every switch, forever, and some live in other modules. Protocol for a closed set → you've paid for extensibility nobody wants and lost exhaustiveness checking.

And note: **this is a question about the product, not the code.** You often can't answer it without asking someone. That's why it's worth asking.

---

## 4. Why "no pattern" is a real answer

Junior engineers believe more structure signals more skill. The opposite is true, and interviewers know it.

Every abstraction has a price paid in *comprehension*: one more indirection, one more name, one more file to open before you understand what happens. Pay it where it buys something. Refuse it where it doesn't.

Situations where the correct answer is a plain function, a struct, or a switch:
- One implementation, and no second one on the horizon.
- The "algorithm" is a single expression used in one place.
- The set of cases is fixed by the domain and won't move.
- The data has no rules — it's just data at a boundary.
- The standard library already does it.

The sentence to practise:

> *"I'd keep this concrete. There's one implementation today, and extracting it later is a small refactor — I'd rather not guess at the shape now."*

That sentence demonstrates that you know the alternative, priced it, and declined. Reciting the pattern demonstrates only that you know its name.

---

## 5. Over-engineering has a specific taste — learn to detect it in yourself

Five self-checks, all cheap:

**Count the types.** A game of noughts and crosses with fourteen types is a signal, regardless of how good each one is.

**Count conformers per protocol.** One conformer, no test double, no second implementation named → that protocol is a redirection sign pointing at one shop.

**Name the variation axis, out loud, for every abstraction.** Can't name it → remove it.

**Run the deletion test.** Mentally delete the pattern. Does the code get worse, or shorter and clearer? If shorter and clearer, it was scaffolding for a building nobody ordered.

**Trace a call.** If following one operation takes more than about three hops, a reader will lose the thread — and readers include you, in four months.

The last two are the ones that catch you in the act, because they're about *what it's like to read*, not about what it's like to design.

---

## 6. And under-engineering has a taste too

The symmetric failure is easier to spot but worth naming:

- The same branch on a type tag appearing in more than one file.
- A class whose honest description needs "and".
- A rule written down in three places.
- A test that needs a network or a real clock.
- "Add a new X" touching eight files.

Notice all five are **measurable**. You don't need taste to detect under-design; you need to look. Over-design is the one that requires judgment, which is why most of this module is about restraint.

---

## 7. Patterns travel in groups

Experienced designs rarely contain one pattern. They contain three or four that reinforce each other, and recognising the *combinations* is a large part of what fluency means.

The recurring shapes:
- Something chooses which algorithm to use → a factory producing a strategy.
- A tree you must walk → recursive containment plus a traversal abstraction.
- Undo where some operations are irreversible → requests as objects, with snapshots for the destructive ones.
- Cross-cutting concerns around a core service → layers, assembled at the composition root, hiding a translator over a vendor SDK.
- Components that must coordinate → observation plus a coordinator, so nobody knows anyone directly.

A design where four patterns quietly cooperate, none of them announced, is what "well designed" looks like. A design where four patterns are *announced* usually has one real one and three decorations.

---

## 8. How to talk about all this

The verbal pattern that scores, every time:

> **pressure → mechanism → cost → alternative declined**

For example: *"pricing rules change per city and we add cities monthly, so I'd put the rule behind a protocol. That costs one protocol and a type per city; the payoff is that a new city is a new file. A closure would work too, but I want the rule's name for the receipt, so a named type earns its place."*

Four sentences, and the listener learns that you understand the problem, chose deliberately, know the price, and considered something simpler.

Contrast: *"I'll use the Strategy pattern here."* — which tells them only that you've read a book.

And keep one refusal in your pocket for every design. An interviewer who hears you decline an abstraction with a reason learns more about your judgment than an hour of correct pattern naming.

---

## 9. Anti-patterns as failure *stories*, not vocabulary

It's worth understanding why each of the classic anti-patterns happens, because they're all reasonable decisions taken one step too far:

- **The God Object** starts as convenience: the thing was already there, so the next method went in it. Nobody decided to build it.
- **The anemic model** starts as separation: data here, logic there, feels tidy. It ends with rules scattered across services and entities that promise nothing.
- **Singleton-itis** starts as pragmatism: passing things down was annoying. It ends with invisible dependencies and untestable code.
- **Pattern fever** starts as diligence: applying what you learned. It ends unreadable.
- **The golden hammer** starts as competence: this worked last time.

Each begins as a locally sensible move. That's why "don't do X" is weak advice — nobody sets out to do X. The useful defence is the periodic self-check in §5, applied to your own design while you still like it.

---

## 10. The thinking procedure

1. Say the variation sentence. If you can't, stop — you're done.
2. Ask whether the variation is real today or imagined.
3. Decide whether the set is open or closed. This picks your mechanism.
4. Start at the bottom of the ladder; climb only when a rung fails.
5. Name the owner of the rule — the type with the data, or a fabricated type if it spans several.
6. Say the cost out loud, and name what you're declining.
7. Run the deletion test on everything you added.
8. Ask "now add X" yourself, and count the files.

Steps 1–6 produce the design. Steps 7–8 are quality control, and they're the ones people skip.

---

## ✅ Concept checkpoint
1. Why does pattern-first thinking reliably produce over-design?
2. Give the four questions in order, and say which one is answered by the product rather than the code.
3. Recite the ladder of mechanisms from cheapest to most expensive.
4. Give three self-checks for over-engineering and say which measures *readability* rather than structure.
5. State the four-part verbal formula for talking about a design decision.
6. Explain why anti-patterns are better understood as stories than as vocabulary.

Then read the module `README.md`.
