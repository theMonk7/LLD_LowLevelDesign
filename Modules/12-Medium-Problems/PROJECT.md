# Module 12 Project — Ride-Hailing Core (Uber-lite)

**Time:** 4–5 hours. The first problem large enough that you must decide what *not* to build.

## Brief

> Riders request a ride from a pickup to a drop location. The system finds nearby available drivers, offers the ride, and assigns the first to accept. Fare = base + per-km + per-minute, with surge multiplying it during high demand. Riders can cancel (free before assignment, a fee after). Drivers go online/offline and can only have one active ride. After the ride, both parties rate each other. The system reports a driver's earnings for a period.

## Requirements
1. Driver states: offline → available → offered → onTrip → available. Illegal transitions rejected.
2. Ride states: requested → assigned → started → completed, plus cancelled from the legal points.
3. Matching: nearest available driver within a radius; if nobody accepts within a timeout, expand the radius once, then fail.
4. Fare computed at completion from actual distance and duration; the **surge multiplier is snapshotted at request time**, not at completion.
5. Cancellation policy: free before assignment, flat fee after, no fee if the driver cancels.
6. Ratings: one per party per ride, 1–5, and a driver's average is derived.
7. Earnings report for a driver over a date range.
8. Every external input — clock, distance calculation, surge level, driver acceptance — is injected.

## Explicitly out of scope
Real maps/routing, payments integration, push notifications, persistence, multi-city.

## Deliverables
1. Source files: `Domain.swift`, `Matching.swift`, `Pricing.swift`, `RideService.swift`.
2. `demo()` covering the ten scenarios below.
3. Tests for: state transitions (legal and illegal), matching with no driver, surge snapshotting, both cancellation paths, fare arithmetic, earnings aggregation.
4. Mermaid class diagram + a state diagram for `Ride`.
5. Decision log: 10–14 bullets, including two abstractions you deliberately did **not** create.

## Acceptance scenarios
| # | Scenario | Expected |
|---|---|---|
| 1 | Request with 3 available drivers | nearest is offered first |
| 2 | Nearest declines | next-nearest offered |
| 3 | Nobody accepts in the radius | radius expands once, then `noDriversAvailable` |
| 4 | Driver accepts | ride assigned, driver state `onTrip`, driver removed from matching |
| 5 | Surge 2.0 at request, 1.0 at completion | fare uses 2.0 |
| 6 | Rider cancels before assignment | no fee |
| 7 | Rider cancels after assignment | flat fee, driver becomes available |
| 8 | Driver cancels after assignment | no rider fee, ride returns to matching |
| 9 | Start a ride that isn't assigned | rejected, no state change |
| 10 | Driver earnings for a week | sums only completed rides in range |

## Rubric (/55)
| Criterion | 0 | 3 | 5 |
|---|---|---|---|
| Entities and boundaries | god `RideManager` | partial | `Rider`, `Driver`, `Ride`, `Fare`, `Location` each justified |
| Ride state machine | booleans | partial | explicit states, illegal transitions rejected |
| Driver state machine | implicit | partial | explicit, one active ride enforced |
| Matching strategy behind a protocol | hardcoded | partial | swappable, and you can name a second implementation |
| Surge snapshotting | computed late | partial | captured at request, proven by a test |
| Cancellation policy | inline `if`s | partial | isolated, all three paths correct |
| Fare arithmetic | `Double` money | partial | `Decimal`, rounding stated |
| Everything injectable | `Date()` inside | partial | clock, distance, surge, acceptance all injected |
| Tests | none | happy path | illegal transitions + failure paths |
| Diagrams | absent | one | class + state, correct notation |
| Decision log incl. 2 non-abstractions | absent | thin | tradeoffs, and what you chose not to build |

**44+/55** → Module 13.

## Extension questions
1. Pooled rides (two riders, one car). Which type stops working, and what replaces it?
2. Scheduled rides for later. Does `Ride` change, or is that a new entity?
3. Driver goes offline mid-trip / loses connectivity. What's the recovery model?
4. 10,000 requests/second in one city. Which part of your design is the bottleneck, and is the fix LLD or HLD?
5. Two riders match the same driver simultaneously. Show the exact interleaving and your fix. (Module 09.)

Send me your implementation and I'll review it against this rubric.
