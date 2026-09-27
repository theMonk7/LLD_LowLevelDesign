# Module 06 — Concepts: Arranging Objects

> Read before the README. Four of these patterns look identical in a diagram. What separates them is **intent**, so intent is what this file is about.

---

## 1. The mental model: wrapping is how you add without editing

You have an object. You want it to be different — different interface, extra behaviour, restricted access, or simpler to use.

You could edit it. But you may not own it, or it may be shared, or editing it risks everyone else who depends on it.

So instead you **put something in front of it**.

> **A wrapper is a decision about what the caller sees, made without touching what's behind it.**

That's the whole family in one line. Everything that follows is a taxonomy of *what decision* the wrapper is making.

---

## 2. The four wrappers, told apart by intent

They share a shape — *something holds something else and forwards to it* — so shape can't distinguish them. Intent can.

**"The interface is wrong for me."**
The thing works, but it doesn't speak your language: wrong method names, wrong units, errors as status codes instead of thrown values. You write a translator. The caller's interface is fixed in advance — you're conforming to a shape you already committed to.

**"I want extra behaviour, and I want to choose it at runtime."**
The interface is right; you want caching, logging, retries, or a price adjustment on top. Crucially the wrapper is *also* the same kind of thing, which means it can be wrapped again, and again — that stackability is the defining property. A caller can't tell how many layers there are, and doesn't need to.

**"I want to control access."**
The interface stays identical and no capability is added. What changes is *whether*, *when*, or *for whom* the call goes through: permission checks, lazy construction, a local stand-in for something remote.

**"This is too complicated; give me one call."**
Several objects, a fixed sequence, a common use case. You invent a simpler front door. Note the difference from the first case: nobody demanded this interface — you designed it for convenience.

### The discriminating questions
- Did the interface change? → translator (Adapter).
- Does the caller gain a capability they asked for, and can it stack? → Decorator.
- Does the caller gain nothing, but something is being restricted or deferred? → Proxy.
- Is a *new, simpler* interface being introduced over *several* objects? → Facade.

Memorise the questions, not the diagrams. The diagrams are the same.

---

## 3. Why the decorator idea is the most valuable one here

Cross-cutting concerns — logging, caching, retrying, metrics, authorisation — have a nasty property: they apply to *many* operations but belong to *none* of them.

Put them inside the operation and you've mixed two responsibilities, made the operation untestable in isolation, and duplicated the concern across every operation that needs it. Put them in the caller and you've duplicated it across every caller.

Layering solves it: each concern becomes its own small thing that satisfies the same contract and delegates inward. The core object stays purely about its job. Each concern can be tested alone. And which concerns are active becomes a **configuration decision made at assembly time** rather than a code decision baked in.

### Two consequences people miss

**Order is semantics.** Caching outside retrying means you retry only on cache misses. Retrying outside caching means you might retry a cache lookup. Same three objects, different behaviour. Layer order is a design decision that deserves a sentence of justification.

**Depth is a cost.** A four-deep stack is elegant on a whiteboard and unpleasant in a debugger, where one call becomes eight stack frames. Layering is not free; it trades local complexity for compositional clarity. That trade is usually worth it around three layers and rarely worth it at six.

---

## 4. Trees: when one and many should look the same

Some structures are recursive by nature: folders contain files and folders; a menu contains items and sub-menus; a discount can be made of discounts; a UI is views inside views.

The naive model distinguishes "a thing" from "a group of things", and then every operation needs to know which it's holding. Totals, traversals, rendering — each grows a branch, and the branch appears everywhere.

The insight: **make the container satisfy the same contract as the thing it contains.** Then "total this" works on a leaf and on a whole tree, and the recursion lives in one method rather than in every caller.

### The tension worth knowing
If containers and leaves look identical, then "add a child" appears on leaves too — where it's meaningless. You can accept that (uniformity, and leaves reject the call) or reject it (only containers accept children, and callers must know which they hold). The first buys simplicity for callers and breaks substitutability; the second is honest and slightly less convenient. There is no free answer, which is exactly why it's worth having an opinion.

---

## 5. Two dimensions that multiply

Watch for requirements with the word "each" twice: *each shape must render in each format*, *each notification must go over each channel*, *each report must export in each layout*.

Model that with a single hierarchy and you get a type per combination. Five shapes and four renderers is twenty types, and adding one renderer adds five more.

The fix is to notice these are **two independent hierarchies**, not one. Keep them separate and let one hold a reference to the other; now it's five plus four, and a new renderer costs one type.

The recognisable smell is a class name containing two nouns joined by "with" or "using": `CircleSvgRenderer`, `EmailUrgentNotifier`. Two nouns in a name means two axes squashed into one.

---

## 6. Sharing to survive scale

Some designs are correct and still fail, because correctness said nothing about memory. A million objects that each carry a copy of identical data will run out of room.

The split to look for: **what is the same across all instances, and what genuinely differs?** A map pin's icon is shared; its coordinate isn't. A chess piece's movement rules are shared; its square isn't. A glyph's outline is shared; its position isn't.

Store the shared part once and let instances point at it. Two requirements make it safe: the shared part must be **immutable** (otherwise you've invented global mutable state) and there must be **one place** that hands out the shared instances (otherwise you get duplicates and the saving evaporates).

The honest framing for an interview: at thirty-two objects this is over-engineering; at a million it's the difference between shipping and crashing. Mentioning it as the scale answer is usually better than implementing it.

---

## 7. How to think when a requirement says "and also…"

Structural patterns are the answer to a specific *shape* of requirement — the bolt-on. Listen for these phrasings:

| Requirement phrasing | What's really being asked |
|---|---|
| "…without changing the existing class" | put something in front of it |
| "…and it should also log / cache / retry" | a stackable layer |
| "…only if the user has permission" | a gate in front |
| "…but their API is different" | a translator |
| "…the caller shouldn't need to know all these steps" | a simpler front door |
| "…a folder can contain folders" | recursive containment |
| "…each X in each Y" | two hierarchies, not one |
| "…millions of them" | share the invariant part |

The habit to build: when you hear "and also", don't reach into the existing class. Ask whether the new concern is a *layer*.

---

## 8. The cost you're paying

Every wrapper adds a hop. That has three prices:

- **Debugging** — more frames, and the thing you're looking at may not be the thing doing the work.
- **Identity** — two references to "the same" object may be different wrappers around it, so equality and identity checks get subtle.
- **Discoverability** — reading the class tells you less, because the interesting behaviour is assembled elsewhere.

The last one is the real cost and the reason the composition root matters so much: if layering is assembled in one readable place, a newcomer can see the whole stack at a glance. If it's assembled ad hoc in five places, nobody knows what's active.

---

## 9. The thinking procedure

1. **Is the interface wrong, or the behaviour insufficient?** Wrong interface → translate. Insufficient behaviour → layer.
2. **Does the caller want this, or are you restricting them?** Want → decorator. Restrict/defer → proxy.
3. **Are you simplifying several things into one call?** → facade, and keep it free of rules.
4. **Is the structure recursive?** → make container and leaf share a contract, and decide the `add` question deliberately.
5. **Do you see two independent axes?** → separate hierarchies before the combinations explode.
6. **Is instance count the problem?** → split shared from unique; make shared immutable.
7. **For every layer you add: say what breaks if you remove it.** No answer → remove it.

---

## ✅ Concept checkpoint
1. Give the four discriminating questions that tell the wrappers apart.
2. Why is layer order a semantic decision? Give an example.
3. State the tension in making containers and leaves share a contract.
4. What naming smell reveals two axes squashed into one?
5. What two properties must shared state have for the memory-sharing idea to be safe?
6. Name the three costs of wrapping, and which one the composition root mitigates.

Then read the module `README.md`.
