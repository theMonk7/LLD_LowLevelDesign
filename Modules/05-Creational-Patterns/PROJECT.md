# Module 05 Project — Pluggable Notification Service

**Time:** 3–4 hours. This is a *machine coding* style project: it must compile, run, and demo.

## Brief

> Build a notification service. A message can be delivered over email, SMS or push. Each channel has different configuration. Senders are expensive to construct (they hold a connection), so they should be reused. Delivery can be configured per notification: priority, retry count, quiet hours, and a template. New channels must be addable by other teams without editing your code.

## Functional requirements
1. Send a notification to a user over one or more channels.
2. Channels are registered at runtime by key (`"email"`, `"sms"`, `"push"`, and whatever a future team adds).
3. Each notification is configured with: template name, priority (`low|normal|urgent`), retry count (0–5), an optional scheduled time, and an optional "respect quiet hours" flag.
4. Invalid combinations must be rejected **before** a notification object exists: urgent + respect quiet hours is contradictory; retries > 5; scheduled time in the past.
5. Channel senders are pooled — at most N live senders per channel.
6. A "template" is a prototype: clone a base template and override fields per recipient without re-parsing.
7. Global configuration (API keys, sender identity) is loaded once at startup.

## Patterns to use — and to justify
You must use **at least four** of the seven, and write one sentence per pattern saying what would break without it:
- **Builder** for notification configuration (requirement 4 is unimplementable with setters)
- **Registry / Factory Method** for channels (requirement 2)
- **Object Pool** for senders (requirement 5)
- **Prototype** for templates (requirement 6)
- **Singleton** for global config (requirement 7) — injectable, per E1
- **Abstract Factory** if you support environment families (prod senders vs sandbox senders)
- **DI** at the composition root — mandatory, not optional

**You will lose marks for using a pattern the requirements don't justify.** Over-engineering is the failure mode this project tests.

## Deliverables
1. `NotificationKit.swift` (or a small file set).
2. `demo()` printing: a successful multi-channel send, a rejected invalid configuration, a pool exhaustion, a template cloned for three recipients, and a *new channel registered from outside the library*.
3. Tests: builder validation (3 cases), registry extension, pool reuse + reset, prototype independence.
4. A class diagram (Mermaid) and a 6–10 bullet decision log.

## Acceptance scenarios
| # | Scenario | Expected |
|---|---|---|
| 1 | Send normal-priority to email + push | both deliver, in registration order |
| 2 | Build with retries = 9 | throws before construction |
| 3 | Build urgent + quietHours | throws |
| 4 | Register a `"slack"` channel from test code and send | works, zero library edits |
| 5 | Acquire 3 senders from a pool of 2 | third throws / waits (your documented choice) |
| 6 | Release a sender, acquire again | same instance, state reset |
| 7 | Clone a template, change the greeting | original unchanged |
| 8 | Two `AppConfig` instances | impossible — won't compile |

## Rubric (/50)
| Criterion | 0 | 3 | 5 |
|---|---|---|---|
| Compiles and demo runs | no | partial | all 8 scenarios |
| Builder validation is cross-field and at `build()` | none | partial | all three rules |
| Registry genuinely open (new channel, zero edits) | closed | partial | proven by a test |
| Pool: exhaustion, reset, double-release | missing | partial | all three handled |
| Prototype: deep, independent | shallow | partial | proven by a test |
| Singleton injectable | global reference | partial | default parameter + protocol |
| Composition root | scattered `init`s | partial | one place wires everything |
| No unjustified patterns | 3+ unnecessary | 1–2 | every pattern justified in one line |
| Tests | none | happy path | validation + extension + pool + prototype |
| Diagram + decision log | absent | one of them | both, and the log names tradeoffs |

**40+/50** → Module 06.

## Extension questions
1. Delivery must now be async with retry and backoff. Which patterns survive unchanged, and which need rework? (Module 09.)
2. A channel needs per-recipient rate limiting. Does that belong in the channel, the service, or a decorator? (Module 06 answers this.)
3. You now need "send via the first channel that succeeds". Which behavioural pattern is that? (Module 07: Chain of Responsibility.)
4. Argue for deleting your Abstract Factory if you only ever ship one environment.

Ask me to review your implementation against this rubric.
