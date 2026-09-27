# Module 11 — Solo Problems

Five designs to build yourself in [`Code/Exercises.swift`](Code/Exercises.swift). Run `swift test --filter M11`.

**Protocol for each:** 5 minutes of requirements and entities on paper, 5 minutes of a class sketch, then code. Time-box each problem to 45 minutes.

### SOLO 1 — Deck of Cards
Model a 52-card deck with deterministic shuffling.
- Build order: for each suit in `Suit.allCases`, every rank in `Rank.allCases`. Deal from the **end** of the array.
- `shuffle()` must be exactly Fisher-Yates: `for i in (1...count-1).reversed() { swap(i, rng(i+1)) }`. The grader passes `{ $0 - 1 }`, which makes every swap a no-op, so any other algorithm fails.
- *Design point:* randomness is injected. A deck that calls `Int.random` internally cannot be tested.

### SOLO 2 — Connect Four
7×6 grid, gravity, four-in-a-row in any direction.
- Row 0 is the **bottom**.
- Error precedence is fixed: `gameOver` → `notYourTurn` → `columnOutOfRange` → `columnFull`.
- *Design point:* check only lines through the last disc, counting outward in both directions — O(1) per move, not a full board scan.

### SOLO 3 — Ring Buffer
Fixed-capacity FIFO, every operation O(1).
- `enqueue` throws when full; `enqueueOverwriting` drops and returns the oldest.
- `elements` must return oldest→newest **across the wrap point** — that's the test that catches a broken index.
- *Design point:* `head`, `tail`, `count`. Using `head == tail` alone to mean empty is ambiguous with full; that's why `count` exists.

### SOLO 4 — Autocomplete
Trie plus ranking.
- Order: frequency descending, then alphabetical.
- An empty prefix matches every word.
- Re-inserting a word **replaces** its frequency and must not double-count `wordCount`.
- *Design point:* where does ranking happen — at insert (keep a sorted list per node) or at query (collect then sort)? The solution sorts at query; say when you'd flip that.

### SOLO 5 — Leaderboard
Incremental scores, top-k, rank, reset.
- Ordering: score descending, then playerID ascending. Ties must be deterministic.
- `reset` zeroes a player but keeps them on the board.
- *Design point:* the solution sorts on every query — O(n log n). Name the structure you'd use at a million players, and why you didn't use it here.

## Stretch (not graded)
1. **Snake game**: grid, direction, growth on eating, death on self-collision. Where does the food generator get injected?
2. Give `Deck` a `Sequence` conformance so `for card in deck` works. What does that say about dealing?
3. Make `Leaderboard` support "top k around me" (my rank ±2). Which structure now?
4. Add a `replay()` to Connect Four that returns the move list. Which pattern did you just need?
5. Turn `RingBuffer` into a fixed-size LRU. What's missing, and which solved problem covers it?
