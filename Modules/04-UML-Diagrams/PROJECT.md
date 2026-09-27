# Module 04 Project — Full UML Pack for a Food Delivery System

**Time:** 2–3 hours. Deliverable: a single `FoodDeliveryUML.md` with six diagrams and a short design-decision log.

## The brief

> Users browse restaurants, add dishes to a cart, and place an order. Payment is by card, UPI or wallet. Once paid, the restaurant accepts and prepares the order. A delivery partner is assigned, picks up, and delivers. Users track the order live and rate it afterwards. Restaurants manage their menus and can mark items unavailable. Surge pricing applies during peak hours.

## Deliverables

1. **Use case diagram** — actors (User, Restaurant, Delivery Partner, Admin) and their goals. 10 minutes maximum.
2. **Entity list** — nouns kept, fake nouns struck, and at least four **implied** entities with a one-line justification each.
3. **Class diagram** — the core model. Must include:
   - correct aggregation vs composition on every containment
   - multiplicity on every relationship
   - `<<protocol>>` boxes for every variation axis you identify (there are at least three: payment method, pricing, partner-assignment strategy)
   - no `Manager`/`Helper` boxes
4. **Sequence diagram** — "user places and pays for an order", including the failure path when the restaurant rejects after payment (what compensates?).
5. **State diagram** — the `Order` lifecycle, from `created` to a terminal state, including cancellation windows and rejection.
6. **Activity diagram** — delivery-partner assignment: no partner available, partner declines, partner times out.
7. **Design decision log** — 8–12 bullets, each in the form *"I chose X over Y because Z"*. This is what an interviewer actually listens to.

## Constraints that make it a design exercise, not a drawing exercise

- An order must keep the **price it was placed at**, even if the menu changes afterwards. Show how in the model.
- A user's cart must not survive a restaurant becoming unavailable in a way that produces a corrupt order.
- Surge pricing must be swappable without touching `Order`.
- Cancellation is allowed before the restaurant accepts, and refundable-with-fee after. Show both in the state diagram.
- A delivery partner can be assigned to only one active order at a time. Express that as multiplicity *and* say where it's enforced.

## Rubric (/40)

| Criterion | 0 | 3 | 5 |
|---|---|---|---|
| Entity discovery | obvious nouns only | some implied | 4+ implied entities justified |
| Relationship correctness | all plain lines | mostly right | ownership correct everywhere |
| Multiplicity | absent | partial | complete, and invariants named |
| Variation points as protocols | none | 1 | 3+, each with a named axis |
| Sequence diagram | happy path only | some errors | failure + compensation shown |
| State diagram | 3 states | main flow | terminal states, guards, cancellation windows |
| Activity diagram | linear | one branch | timeouts and declines handled |
| Price snapshotting | missing | mentioned | modelled explicitly |
| Decision log | absent | vague | 8+ "X over Y because Z" |

**32+/40** → Module 05.

## Extension questions
1. Where would you put "restaurant is closed" — a state on `Restaurant`, a computed property from opening hours, or both? What breaks with each?
2. Live tracking: does `Order` hold the partner's location? Argue why not, and what should.
3. A user orders from two restaurants in one checkout. What changes in your class diagram, and what does that tell you about the `Order`/`Cart` boundary?
4. Redraw your class diagram at the *package* level (domain / application / infrastructure). Which arrows now cross layers the wrong way?

Ask me to review your UML pack against this rubric.
