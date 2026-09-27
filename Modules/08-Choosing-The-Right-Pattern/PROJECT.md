# Module 08 Project — Pattern-Selection Written Exam

**Time:** 2 hours. No code. This trains the part of the interview where you talk.

## Format

For each of the 10 scenarios below, write:
1. **The variation sentence** — "The ___ varies by ___."
2. **Your choice** — a pattern, a combination, or "no pattern".
3. **The cheaper alternative you rejected**, and why.
4. **The cost** of your choice, in types and indirection.
5. **The extension test** — "when requirement X arrives, I touch ___ files."

Answer in a file `PatternExam.md`. Two to five sentences per scenario. Then self-grade with the rubric.

## Scenarios

1. **Ride pricing.** Fares differ by city, vehicle type, time of day, and surge. New cities launch monthly. Finance must be able to audit which rule produced a fare.

2. **Feature flags.** A flag can be on/off, on for a percentage of users, on for a user list, or on after a date. Product wants to add new flag kinds without an app release where possible.

3. **Image loading.** Images come from network, disk cache, or memory cache. Each layer should be optional, testable, and composable, and a failing network fetch should retry twice.

4. **Order lifecycle.** An order moves through created → paid → packed → shipped → delivered, with cancellation allowed until packed and refunds after. Six methods currently start with `switch status`.

5. **Checkout form.** Country changes reset state; state changes reset city; a promo code field enables only when the cart total exceeds a threshold; the submit button depends on all of them.

6. **Export.** A report can be exported as PDF, CSV, XLSX and (next quarter) JSON. The report's internal node types have been stable for three years.

7. **Push notification delivery.** Try FCM; if it fails, try APNs; if that fails, fall back to SMS. Each attempt must be logged and each has its own SDK with a different API.

8. **App configuration.** Read from a bundled JSON at launch, overridable by a remote config fetch, overridable again by a debug menu in internal builds.

9. **Game replay.** A chess app must let users step backwards and forwards through a finished game, and also support "undo" during live play.

10. **Analytics.** Events go to three SDKs. Some builds ship with none. Event names must be type-safe. A new SDK is added roughly yearly.

## Rubric (/50, 5 per scenario)
| Points | Standard |
|---|---|
| 5 | Variation sentence is precise; choice justified by it; cheaper alternative named and rejected with a reason; cost stated; extension test concrete |
| 3 | Correct choice, thin justification, no alternative considered |
| 1 | Pattern named with no reasoning, or a pattern the requirements don't justify |
| 0 | Wrong axis of variation identified |

**Deduct 2 points** anywhere you proposed a pattern the requirements don't support — over-engineering is scored negatively here, exactly as in a real interview.

**40+/50** → Module 09.

## Self-review questions
- How many of your 10 answers were "no pattern" or "a closure/enum"? If zero, you are probably over-engineering.
- How many were combinations rather than a single pattern? Real designs are usually combinations.
- Which scenario did you find hardest, and was the difficulty in choosing the pattern or in naming the variation? (It's almost always the latter — that's the skill.)

Send me your `PatternExam.md` and I'll grade it against this rubric with line-by-line feedback.
