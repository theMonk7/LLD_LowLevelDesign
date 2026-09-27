# Module 14 Project — Design an Image-Loading Library (SDWebImage clone)

**Time:** 4–5 hours. This is the single most-asked iOS design prompt at senior level.

## Brief

> Design a reusable image-loading library. Callers ask for an image by URL and get back image data. Images are cached in memory and on disk. Concurrent requests for the same URL must produce one network call. Requests can be cancelled. Memory is bounded by a cost limit; disk by size and age. The library must be usable from a scrolling list without stutter, and fully testable without a network.

## Requirements
1. **Public API** — one primary entry point; the caller supplies only a URL and gets data or a typed error.
2. **Three layers** — memory → disk → network, each behind its own protocol, each independently replaceable and testable.
3. **Coalescing** — N concurrent requests for the same URL produce exactly one network fetch, and all N receive the result.
4. **Cancellation** — a caller that goes away releases its interest; the fetch is cancelled only when no one is waiting.
5. **Eviction** — memory cache bounded by a cost limit with LRU eviction; disk bounded by total size and max age.
6. **Error taxonomy** — network, decoding/corrupt data, cancelled, and not-found are distinguishable.
7. **Failures are never cached** (but a 404 *may* be negatively cached with a TTL — decide and justify).
8. **Transformations** — an optional processing step (resize/round corners) applied after download, with the *processed* result cached under a key that includes the transformation.
9. **Instrumentation** — hit rates for memory and disk, and in-flight count.
10. **No UIKit in the core** — the core deals in `Data`; a thin platform layer converts to `UIImage`.

## Deliverables
1. Source: `ImageLoader.swift`, `Caches.swift`, `Fetching.swift`, `Transform.swift`.
2. `demo()` showing: cold fetch, memory hit, disk hit after a memory flush, 50-way coalescing, a cancelled request, and an eviction.
3. Tests: coalescing under `withTaskGroup`, eviction order, failure not cached, transformation cache-key separation, cancellation.
4. Mermaid class diagram + a sequence diagram for "cache miss with two concurrent callers".
5. `DECISIONS.md`: 10–14 bullets including the negative-caching decision, the cancellation policy, and one thing you deliberately did not build.

## Acceptance scenarios
| # | Scenario | Expected |
|---|---|---|
| 1 | Cold fetch | network called once, memory and disk populated |
| 2 | Second request for the same URL | memory hit, no disk or network access |
| 3 | Memory cleared, request again | disk hit, no network |
| 4 | 50 concurrent requests, same URL | 1 network call, 50 results |
| 5 | Fetch fails | no cache entry, in-flight entry cleared, next request retries |
| 6 | Two different transformations, one URL | 1 download, 2 cached processed entries |
| 7 | Memory cost limit exceeded | LRU eviction, documented order |
| 8 | Disk entry older than max age | treated as a miss and refreshed |
| 9 | Single caller cancels | fetch cancelled |
| 10 | One of two callers cancels | fetch continues, the other still gets the image |

## Rubric (/55)
| Criterion | 0 | 3 | 5 |
|---|---|---|---|
| Layering behind protocols | one class | partial | three independent, swappable layers |
| Coalescing correctness | 50 fetches | works sequentially | atomic publish before suspension, proven by a concurrent test |
| Cancellation semantics | none | naive | reference-counted; scenario 10 passes |
| Eviction (memory) | unbounded | count-based | cost-based LRU, order tested |
| Eviction (disk) | none | size only | size + age |
| Error taxonomy | one error | two | four, distinguishable |
| Negative caching decision | unconsidered | mentioned | decided, justified, implemented or deferred explicitly |
| Transformation cache keys | collide | partial | key includes the transform, one download |
| Core free of UIKit | imports UIKit | partial | `Data` core + thin platform layer |
| Tests | none | happy path | concurrency, eviction, cancellation |
| Diagrams + decisions | absent | one | both, with the concurrent-callers sequence |

**44+/55** → Module 15.

## Extension questions
1. Prefetching for the next 10 cells. What changes, and what's the risk of getting priority wrong?
2. A cell is reused while its image is in flight. Where do you check that the URL still matches, and why not inside the loader?
3. Progressive JPEG rendering. Which part of your API has to change shape? (Hint: one value becomes a stream.)
4. Same URL requested with two different transformations *concurrently*. Does your coalescing key on the URL or on URL+transform, and what does each choice cost?
5. Your library ships to 50 apps. What's your deprecation policy for the public API you just designed?

Send me your implementation and `DECISIONS.md` and I'll review it as a senior-iOS interviewer would.
