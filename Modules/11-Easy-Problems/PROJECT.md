# Module 11 Project — Blackjack, Start to Finish

**Time:** 2.5 hours, timed. This is the first end-to-end machine-coding rehearsal, and it reuses two things you just built (`Deck`, and the turn-based engine shape).

## Brief

> Implement single-deck Blackjack for one dealer and 1–4 players. Each player places a bet, receives two cards, then hits or stands. Aces count as 11 or 1, whichever keeps the hand under 22. The dealer draws until 17 or higher. Blackjack (21 on the first two cards) pays 3:2; a normal win pays 1:1; a push returns the bet. Players may double down on their first action; splitting is out of scope. The shoe reshuffles when fewer than 15 cards remain.

## Requirements
1. Deterministic under test — shuffling and any randomness injected.
2. A player cannot act out of turn, act after standing, or bust and keep playing.
3. Hand value handles multiple aces correctly (A + A + 9 = 21, not 31).
4. Payouts exactly as specified, including blackjack vs 21-on-three-cards (not the same thing).
5. Double down: doubles the bet, draws exactly one card, then forces a stand.
6. The shoe reshuffles when short, and a round never runs out of cards mid-deal.
7. Balances never go negative; a bet larger than the balance is rejected before the round starts.

## Deliverables
1. `Blackjack.swift`.
2. `demo()` playing a scripted 3-round game with a fixed card sequence, printing hands and payouts.
3. Tests: hand values with aces, each payout case, illegal actions, double down, reshuffle.
4. A 6–10 bullet decision log, including one thing you deliberately did *not* abstract.

## Acceptance scenarios
| # | Scenario | Expected |
|---|---|---|
| 1 | A + A + 9 | 21 |
| 2 | A + K | blackjack, pays 3:2 |
| 3 | 7 + 7 + 7 | 21 but not blackjack, pays 1:1 |
| 4 | Player 22 | bust, loses immediately, dealer doesn't draw for them |
| 5 | Dealer 16 → draws; dealer 17 → stands | correct |
| 6 | Both 20 | push, bet returned |
| 7 | Hit after standing | rejected with a typed error, no state change |
| 8 | Double down then hit | rejected |
| 9 | Bet > balance | rejected before any cards are dealt |
| 10 | 14 cards left at round start | reshuffle happens, round completes |

## Rubric (/45)
| Criterion | 0 | 3 | 5 |
|---|---|---|---|
| Entities: `Card`, `Hand`, `Player`, `Dealer`, `Round` | one god class | partial | clean, each with one responsibility |
| Ace handling | wrong | single ace only | any number of aces |
| Payout rules incl. blackjack vs 21 | wrong | partial | all cases |
| Turn/state enforcement | trusts caller | partial | typed errors, no state change on failure |
| Determinism (injected shuffle) | `Int.random` inside | partial | fully injected |
| Reshuffle logic | missing | partial | correct, never runs dry |
| Money handling | `Double` | `Int` paise/cents | `Decimal` or integer minor units, no negatives |
| Tests | none | happy path | all 10 scenarios |
| Decision log incl. a non-abstraction | absent | thin | tradeoffs + one deliberate omission |

**36+/45** → Module 12.

## Extension questions
1. Add splitting. Which type changes shape, and why is `Hand` suddenly the wrong granularity?
2. Add a second player strategy ("always stand on 17"). Which pattern, and did you already have the seam?
3. Multi-deck shoe with card counting. What does the counter observe, and which pattern is that?
4. Make it multiplayer over a network. Where's the first race condition? (Module 09.)

Send me your `Blackjack.swift` and I'll review it against this rubric.
