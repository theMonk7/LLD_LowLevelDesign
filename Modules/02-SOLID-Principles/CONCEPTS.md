# Module 02 — Concepts: Why These Five Rules Exist

> Read before the README. No code — the point here is to understand the *pressure* each principle relieves, so you can recognise that pressure in your own work without being told which letter applies.

---

## 1. The mental model: SOLID is five answers to one question

The question is the one from Module 00:

> **"When this changes, what breaks, and how far does the damage spread?"**

Each principle attacks a different *mechanism* by which damage spreads.

| Damage spreads because… | Principle |
|---|---|
| …one file holds rules owned by different people | **S**RP |
| …adding a case means editing working code | **O**CP |
| …a substitute behaves differently from the thing it replaced | **L**SP |
| …you're forced to implement things you don't need | **I**SP |
| …policy is welded to a specific mechanism | **D**IP |

That's it. Five failure modes, five counter-measures. If you remember nothing else, remember that they are **not style rules**. They are damage-containment rules, and each one has a visible, measurable symptom.

---

## 2. Single Responsibility: the principle everyone misquotes

"A class should do one thing" is a bad paraphrase, because "one thing" is infinitely divisible. Is parsing one thing? Is parsing a date one thing? Is reading a digit one thing?

The real formulation is about **people**:

> **A module should answer to one source of change — one stakeholder, one team, one reason.**

The finance team changes tax rules. The infrastructure team changes where data is stored. The growth team changes the welcome email. If those three live in one file, then three groups, on three schedules, for three unrelated reasons, are editing the same code — and they will collide, and each collision risks breaking the other two.

### The intuition pump
Think of a **document that three departments must sign off**. Every edit needs three approvals, even when only one department cares. That's what a multi-responsibility class does to a codebase: it makes every change expensive by forcing unrelated concerns into the same review.

### Why "one thing" misleads you
It pushes people toward splitting by *mechanics* — a class per method, six files where one would do. That's not higher cohesion; it's the same responsibility smeared across six files, which is strictly worse: you now read six files to understand one rule.

The correct split is along **lines of change**, not lines of syntax. Two things that always change together belong together, however different they look. Two things that change for different reasons belong apart, however similar they look.

### The detector
Say the class's job out loud. If you need the word "and", you've found the seam. If you reach for `Manager`, `Helper`, `Service` (with no domain meaning), `Util`, `Processor` — you're naming a container, not a responsibility, because there wasn't one.

---

## 3. Open/Closed: the economics of editing versus adding

The principle sounds paradoxical — how can something be closed to modification and still gain features? The resolution is that there are two ways to add behaviour:

- **Edit** existing code. It must be re-read, re-reviewed, re-tested, and it can break existing callers.
- **Add** new code. Nothing that worked yesterday changed, so nothing that worked yesterday can break.

Open/Closed says: *arrange your design so that the common kind of change is an addition.*

### The pressure it relieves
The symptom is a branch on a type tag that you keep revisiting — and, crucially, that appears in **more than one place**. One switch is an inconvenience. The same switch in four files is a defect generator, because eventually someone updates three of them.

### The part almost everyone gets wrong
OCP is **directional**. You cannot be open to every kind of change; making a design flexible along one axis makes it rigid along another. A design that makes "new payment method" trivial usually makes "add a field to every payment" annoying.

So the real skill isn't "apply OCP". It's:

> **Identify the axis along which change actually arrives, and be open on that axis only.**

Which means you have to *ask*. "What's more likely — new payment methods, or new fields on a payment?" That question is worth more than any pattern.

### And the honest counterweight
In a language with exhaustive pattern matching, a closed set of cases plus a compiler-checked switch is *better* than an extensible protocol — because the compiler becomes the thing that tells you every place to update. OCP is about sets that **grow**. If the set is fixed (four suits, three states of a coin), embrace the switch and say why.

---

## 4. Liskov Substitution: the principle about promises, not syntax

The compiler can check that a subtype has the right method names and parameter types. It cannot check that the subtype *behaves* like the thing it replaces. Liskov is the rule that covers the part the compiler can't see.

> **A subtype must be usable by code that was written for the supertype, by someone who has never heard of the subtype.**

That last clause is the whole thing. The caller was written against a promise. If the substitute quietly makes that promise weaker, the caller is now wrong — and the caller's author will never know, because they can't see your class.

### The four ways to break the promise
Learn these as *feelings*, not as formal rules:

- **"You must give me less than the parent accepted."** (Strengthened precondition.) The caller passes something the parent allowed, and you reject it.
- **"I give you back less than the parent guaranteed."** (Weakened postcondition.) The parent promised a sorted result; you return it unsorted.
- **"I let the object reach a state the parent forbade."** (Broken invariant.) The parent guaranteed non-negative; you allow overdraft.
- **"I let you change something the parent said was fixed."** (History violation.) The parent was immutable after construction; you added a setter.

### The tell you can spot in five seconds
An override that **throws**, **returns nil**, or **does nothing** where the parent did something real. Each of those is the subtype saying "actually, I can't". The caller has no way to know, so they'll find out at runtime.

When you feel the urge to write that override, the hierarchy is wrong. The fix is almost never cleverness inside the subtype; it's **a smaller promise** — split the type so that things that can't write aren't asked to.

### Why it's the most violated
Because inheritance is taught as reuse (Module 01 §5), people inherit to get a method and then patch the parts that don't fit. Each patch is a small broken promise. Individually harmless, collectively the reason nobody trusts the hierarchy.

---

## 5. Interface Segregation: fat contracts force lies

If a contract has nine obligations and a type can honour four, one of two things happens. Either the type lies (empty methods, "not supported" errors — see Liskov above), or callers start type-checking to find out what they really got — which destroys the point of having an abstraction.

> **A contract should be shaped by what a *caller* needs, not by what an implementer happens to offer.**

That reframing is the useful part. Don't ask "what can this class do?" Ask "**what does each caller actually use?**" If caller A uses three methods and caller B uses four different ones, you have two contracts wearing one name.

### The intuition pump
A fat interface is a **job description that lists every task in the company**. Nobody can honestly apply. Split it into roles and suddenly the right people fit the right roles, and you can hire a specialist without pretending they can do everything.

### The detector
Empty method bodies. Every one is the compiler telling you the contract is too wide. In Swift, the same smell hides inside protocol extensions with meaningless defaults — the default silences the warning but the design problem stays. Ask honestly: *is this a sensible default, or an excuse?*

### Why small protocols also help elsewhere
They make Liskov easy (a narrow promise is easy to keep), they make testing easy (fewer methods to fake), and they make dependency inversion sharper (you depend on exactly what you need, so you're affected by fewer changes).

---

## 6. Dependency Inversion: who gets to decide?

Every program has two kinds of code: **policy** (what the business means) and **mechanism** (how it happens to be done — this database, this HTTP client, this file format).

Left alone, policy ends up depending on mechanism, because that's the order you write them in: you need to save an order, so you call the database.

DIP says: **flip it.** The policy declares what it needs in its own words; the mechanism conforms to that declaration.

> **The direction of the arrow matters more than the existence of the arrow.**

### Why this one changes everything
Three consequences, all large:

1. **Testability.** Policy can be exercised without a database, a network, or a clock — because those were *parameters*, not hard-coded choices.
2. **Replaceability.** Swapping mechanism becomes a change at the wiring layer, not a change in the business rules.
3. **Comprehensibility.** Policy reads in domain language. Code that says "save this order" is clearer than code that assembles SQL, and the clarity is not cosmetic — it's the difference between a rule you can audit and one you have to decode.

### The half that people miss
DIP has two sentences, and the second one is the sharp one: **the abstraction must not be shaped by the mechanism.** If the "storage" contract talks about queries, or rows, or connection strings, then the policy still depends on the database — you've just added a layer of paint. A true inversion is phrased entirely in the language of the problem domain.

The test: *could a completely different mechanism implement this contract without contortion?* If only a SQL database could, it isn't inverted.

### The related question you'll be asked constantly
*"How would you test this?"* — is, nine times out of ten, a DIP question in disguise. If the honest answer requires a network, a real clock, or the filesystem, a dependency is hard-coded that should have been handed in.

---

## 7. How the five fit together (the one-sentence version)

> **Split responsibilities (S) into narrow contracts (I), depend on those contracts rather than on concretions (D), so new behaviour arrives as new code (O) that existing callers can trust (L).**

Read it twice. Every design pattern in Modules 05–07 is a named, pre-packaged way of executing that sentence in a specific situation.

And notice the dependencies between the letters: ISP makes LSP achievable (narrow promises are keepable). DIP is what makes OCP possible (you can't add a conformer if callers name concrete types). SRP is what makes any of it comprehensible.

---

## 8. When to *not* apply them

This section matters as much as the rest, because SOLID misapplied produces the over-design failure mode from Module 00.

Every principle buys change-containment with **indirection**, and indirection is paid for in comprehension. So:

- **One implementation, no second one in sight** → don't invert. A concrete type with a good name is honest.
- **The variation is hypothetical** → you're designing for a guess. Guessed abstractions are usually the wrong shape, and wrong shapes are harder to fix than no shape.
- **A leaf function with no dependencies** → there's nothing to invert. Thirty lines of pure computation needs no architecture.
- **A prototype you'll delete** → structure is an investment; don't invest in something with a two-week lifespan.

The mature position, and the one that reads best in an interview:

> *"I know how I'd make this extensible; I don't think we should yet, because there's one case and extracting it later is cheap."*

That sentence demonstrates that you know the principle **and** can price it. Reciting the principle demonstrates only the first half.

---

## 9. The thinking procedure

When you look at any piece of code or any design sketch:

1. **Who would ask for this to change?** More than one group → SRP.
2. **What arrives next — a new case, or a new field?** New cases, frequently → OCP on that axis.
3. **Is anything pretending to be something it can't be?** Throwing overrides, nil returns, empty methods → LSP and ISP.
4. **What does each caller actually use?** Disjoint subsets → ISP.
5. **Does the business logic name a specific technology?** → DIP.
6. **Could I test the rules without I/O?** No → DIP again.
7. **For each abstraction I've added: can I name the second implementation?** No → delete it.

Steps 1–6 find missing structure. Step 7 removes structure you didn't need. Both directions matter; most people only practise the first.

---

## ✅ Concept checkpoint
1. Restate SRP in terms of *people*, and give an example where two similar-looking things belong apart.
2. Why is OCP directional, and what must you do before applying it?
3. Give the five-second tell for a Liskov violation, and say why the compiler can't catch it.
4. Reframe "this protocol is too big" as a question about callers.
5. State DIP's second sentence and give an example of an abstraction that violates it while looking fine.
6. Give a situation where applying a principle would be the wrong call, and say how you'd phrase the refusal.

Then read the module `README.md`.
