# Module 13 Project — Multiplayer Chess Server Core

**Time:** 6–8 hours across two sittings. The capstone design problem: big enough that scoping, not coding, decides the outcome.

## Brief

> Build the core of an online chess service. Players are matched by rating. A match has two players, a board, a clock per player (with increment), and a move history. Moves are validated server-side. Games end by checkmate, stalemate, resignation, timeout, or draw agreement. Ratings update with Elo after each game. Spectators can watch live and replay finished games. A disconnected player has 60 seconds to reconnect before forfeiting.

## Scoping instruction (this is graded)
You will not build all of it. **Before writing code, produce three lists** — in scope, out of scope, deferred-with-a-plan — and stick to them. A reviewer should be able to tell from your lists alone whether your design is coherent.

Suggested core: matchmaking, match lifecycle, move validation (reuse/extend the solved chess engine), clocks, termination conditions, rating updates.
Suggested deferral: networking, persistence, spectator fan-out, anti-cheat, tournaments.

## Requirements
1. **Matchmaking:** pool of waiting players; pair the two closest in rating within a widening tolerance over time. Nobody is matched twice.
2. **Match lifecycle:** waiting → active → finished(reason). Illegal transitions rejected.
3. **Move validation:** server-side; an illegal move is rejected without changing state and does not consume clock time beyond what has elapsed.
4. **Clocks:** each player has a remaining time and an increment. The mover's clock runs; making a move adds the increment. Reaching zero ends the game by timeout. **Time is injected.**
5. **Termination:** checkmate, stalemate, resignation, timeout, draw agreement, threefold repetition (or state why you deferred it).
6. **Rating:** Elo update on completion; a draw is not a no-op.
7. **Reconnection:** a disconnect starts a 60-second grace timer; reconnecting inside it resumes, otherwise the player forfeits.
8. **Replay:** a finished game can be replayed move by move from the recorded history.

## Deliverables
1. Source files: `Matchmaking.swift`, `Match.swift`, `Clock.swift`, `Rules.swift`, `Rating.swift`.
2. `demo()` playing a full scripted game ending in checkmate, plus one ending on time.
3. Tests: matchmaking pairing and widening, illegal move rejection, clock accounting, each termination reason, Elo maths, reconnection inside and outside the grace window.
4. Mermaid class diagram **and** a state diagram for `Match`.
5. `SCOPE.md` with the three lists, and `DECISIONS.md` with 12–16 bullets including three things you deliberately did not abstract.

## Acceptance scenarios
| # | Scenario | Expected |
|---|---|---|
| 1 | Three players waiting, ratings 1200/1210/1600 | 1200 and 1210 paired |
| 2 | No one within tolerance | stays in the pool; tolerance widens with waiting time |
| 3 | Illegal move | rejected, board unchanged, turn unchanged |
| 4 | Move that exposes own king | rejected as a distinct error |
| 5 | Checkmate | game ends, reason recorded, ratings updated |
| 6 | Stalemate | draw, not a win |
| 7 | Player's clock hits zero | timeout loss, even mid-think |
| 8 | Increment applied on each move | clock arithmetic exact |
| 9 | Disconnect, reconnect at 30 s | game resumes |
| 10 | Disconnect, reconnect at 90 s | forfeit recorded |
| 11 | Replay a finished game | every position reproduced |
| 12 | Move after the game ended | rejected |

## Rubric (/70)
| Criterion | 0 | 3 | 5 |
|---|---|---|---|
| `SCOPE.md` written first and honoured | absent | vague | three lists, followed |
| Entity decomposition | god `GameManager` | partial | `Match`, `Board`, `Clock`, `Player`, `Rules`, `Pool` each justified |
| Match state machine | booleans | partial | explicit, illegal transitions rejected |
| Move validation layering | one function | partial | pseudo-legal then king-safety |
| Checkmate vs stalemate | conflated | one right | both correct |
| Clock model | wall-clock reads inside | partial | injected time, increment exact |
| Timeout detection | missing | on move only | detected even without a move |
| Matchmaking policy behind a protocol | hardcoded | partial | swappable, second impl named |
| Elo implementation | wrong | win/loss only | draws and K-factor handled |
| Reconnection window | missing | partial | both paths, injected clock |
| Replay from history | missing | partial | positions reproduced exactly |
| Tests | none | happy path | all 12 scenarios |
| Diagrams | absent | one | class + state, correct notation |
| `DECISIONS.md` incl. 3 non-abstractions | absent | thin | tradeoffs and deliberate omissions |

**56+/70** → Module 14. This is the hardest rubric in the course; scoring 45 on a genuinely attempted version is a better outcome than 65 on a narrowed brief.

## Extension questions
1. Where is the concurrency boundary — per match, or global? What does each choice cost? (Module 09.)
2. A player makes a move at the exact instant their clock expires. Who wins, and where is that decided?
3. Spectators must see moves live without slowing the players. Which pattern, and what's the failure mode?
4. Threefold repetition needs position history. What's the cheapest correct representation, and what does it do to memory over a 200-move game?
5. Which single abstraction in your design would you delete if told the product will only ever support blitz chess?

Send me `SCOPE.md`, `DECISIONS.md` and your source and I'll review it as a hiring-bar interviewer would.
