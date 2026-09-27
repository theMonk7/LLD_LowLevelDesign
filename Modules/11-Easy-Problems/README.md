# Module 11 — Easy Problems (7 solved + 5 solo)

> **Start with [`CONCEPTS.md`](CONCEPTS.md).** It carries the mental models, the intuition and the
> *why* behind everything below — no code. This file is the detailed reference you read second,
> once the ideas have a shape to attach to.

**Goal:** build fluency on problems small enough to finish in 45 minutes, so the framework becomes automatic before the hard problems arrive.

**How to use this module:**
1. For each solved problem, **read the requirements only**, close the file, and design it yourself for 20 minutes.
2. Then read the walkthrough here and the code in [`Solutions/Solved.swift`](Solutions/Solved.swift).
3. Write down every decision you made differently — and whether yours was worse, equal, or better.
4. Then do the five solo problems in [`Code/Exercises.swift`](Code/Exercises.swift) and run `swift test --filter M11`.

Reading a solution you haven't attempted teaches almost nothing. The 20 minutes of struggle is the lesson.

---

# SOLVED 1 — Tic-Tac-Toe

### Requirements
Two players alternate placing marks on an N×N board. First to fill a row, column or diagonal wins. A full board with no winner is a draw. Invalid moves must be rejected, not crash.

### Clarifying questions worth asking
- Fixed 3×3 or configurable N? *(Assume configurable — it costs nothing and shows extensibility.)*
- Two humans, or is an AI player in scope? *(Out of scope, but the design should allow it.)*
- Should the engine enforce turn order, or trust the caller? *(Enforce — invariants belong in the type.)*

### Entities
`Mark` (value, enum) · `GameResult` (value, enum with associated value) · `TicTacToe` (entity, owns the board and the invariants) · `MoveError` (typed errors).

There is no `Board` class here, and that's deliberate: for a 3×3 grid a `[[Mark?]]` inside the game is simpler, and a `Board` type with three methods would be a Poltergeist (Module 08 §6). At 8×8 with piece rules — chess, Module 13 — a `Board` earns its place.

### Key decisions
```swift
public private(set) var current: Mark = .x
public private(set) var result: GameResult = .inProgress
```
State is readable, never writable from outside. Every rule is enforced in `play`:

```swift
guard result == .inProgress else { throw MoveError.gameOver }
guard mark == current else { throw MoveError.notYourTurn }
guard (0..<size).contains(row), (0..<size).contains(col) else { throw MoveError.outOfBounds }
guard board[row][col] == nil else { throw MoveError.cellTaken }
```
**Validate-then-mutate**: a rejected move leaves the game byte-identical.

The win check is the interesting part:
```swift
private func wins(_ mark: Mark, lastRow r: Int, lastCol c: Int) -> Bool
```
Only lines through the **last move** can be newly complete, so this is O(N) rather than O(N²). Interviewers notice.

### Patterns used
None. That's the correct answer for Tic-Tac-Toe, and saying so is a point in your favour. A `WinStrategy` protocol with one implementation would be over-engineering (Module 08 §5).

### Extension questions
1. Add an AI player. *Now* you want a `Player` protocol with `HumanPlayer`/`RandomAI`/`MinimaxAI` — Strategy, justified by a real second implementation.
2. Make it N-in-a-row on an M×M board. What changes? (`wins` counts runs instead of full lines.)
3. Add undo. (Command, Module 07 E4.)
4. Two clients play over a network. Where's the race? (Module 09.)

---

# SOLVED 2 — Snake & Ladder

### Requirements
Players take turns rolling a die and moving. Ladders move you up, snakes move you down. First to land exactly on the final square wins. Overshooting means you don't move.

### Clarifying questions
- Exact landing required, or does overshooting win? *(Decide and state it — this is the classic house-rule ambiguity.)*
- Does rolling a 6 grant another turn? *(Assume no.)*
- Can two players share a square? *(Assume yes.)*

### The design insight
**A snake and a ladder are the same thing.** Both are "from square X, go to square Y". One type, one dictionary:

```swift
public struct Jump: Equatable {
    public let from: Int
    public let to: Int
    public var isLadder: Bool { to > from }
}
private let jumps: [Int: Int]
```
Candidates who write `Snake` and `Ladder` classes with identical bodies have missed the abstraction — and their `isSnake`/`isLadder` checks spread through the move logic. Finding that two nouns are one concept is exactly the skill being tested.

### The testability decision
```swift
public protocol Dice { func roll() -> Int }
```
Randomness is injected (DIP, Module 02 §D). The demo scripts the rolls:
```swift
var rolls = [4, 6, 2, 5].makeIterator()
let dice = StandardDice(rng: { rolls.next() ?? 1 })
```
A game engine that calls `Int.random` internally is untestable. This is the same move as injecting a `Clock`.

### Patterns used
Strategy (the `Dice` protocol), Dependency Injection. Nothing else is justified.

### Extension questions
1. Support "roll a 6 to start". Where does that rule live — the game or the player?
2. Multiple dice, or a die with a different number of sides. (Already supported — note that.)
3. Add a `Board` that validates jumps (no chains, no jump from the final square). Who enforces it, and when?
4. Animate a turn-by-turn replay. (Command or an event log.)

---

# SOLVED 3 — Browser History

### Requirements
Visit a URL, go back N steps, go forward N steps. Visiting a new page clears the forward history.

### The design
Two stacks and a current page. That's the whole design, and recognising it immediately is the point.

```swift
public func visit(_ url: String) {
    backStack.append(current)
    current = url
    forwardStack.removeAll()        // ← the rule everyone forgets
}
```
`forwardStack.removeAll()` is the same invariant as the redo stack in Module 07 E4. Whenever you see "a new action invalidates the alternate history", that's the shape.

`back(_:)` and `forward(_:)` clamp rather than throw:
```swift
for _ in 0..<steps {
    guard let previous = backStack.popLast() else { break }
    ...
}
```
Asking for 100 back-steps with 3 available lands on the oldest page — which is what a browser does. Deciding between clamping and throwing is a product question; say which you chose.

### Alternative design, and why it's worse here
A single array plus an index is also O(1) and uses less memory. It's fine — but `visit` then has to truncate the array, which is O(n), and the two-stack version expresses "back" and "forward" so directly that the code reads like the requirement. Both are defensible; be ready to compare.

### Extension questions
1. Multiple tabs, each with its own history, plus a global "recently closed". (Composition — a `Tab` owns a `BrowserHistory`.)
2. Cap history at 100 entries. Which data structure now? (A ring buffer — solo problem 3.)
3. Persist and restore across launches. What must `BrowserHistory` expose, and what should it *not*?

---

# SOLVED 4 — Min Stack

### Requirements
A stack with `push`, `pop`, `top` and `min`, all in O(1).

### The design
The naive `min` scans — O(n). The trick: **store the running minimum alongside each element**.

```swift
private var entries: [(value: Element, min: Element)] = []

public mutating func push(_ value: Element) {
    let newMin = entries.last.map { Swift.min($0.min, value) } ?? value
    entries.append((value, newMin))
}
```
`pop` needs no special handling at all — removing the entry removes its minimum with it.

Generic over `Element: Comparable`, so it's a min-stack of anything ordered, not just `Int`. Small thing, right instinct.

### Tradeoff to state
O(n) extra memory for O(1) `min`. The two-stack variant (a second stack holding only new minima) uses less memory when there are long non-decreasing runs. Both are standard; knowing there's a choice is what's assessed.

### Extension questions
1. Add `max` in O(1). (Store both, or generalise to a `reduce`-style accumulator.)
2. Make it thread-safe. (Module 09 — note that the `struct` has value semantics, so sharing it is already a different problem.)
3. Why is `MinStack` a `struct` here while `LRUCache` is a `class`? (Identity — Module 01 §2.)

---

# SOLVED 5 — LRU Cache

### Requirements
Fixed capacity. `get` and `put` in O(1). When full, evict the least recently used entry. A `get` counts as a use.

### The design
This is *the* classic "two data structures" problem.

| Need | Structure |
|---|---|
| O(1) lookup by key | `Dictionary` |
| O(1) "move to most recent" | doubly-linked list |

An array gives O(1) lookup but O(n) move-to-front. A `Dictionary` alone has no ordering. You need both, and the dictionary stores **node references**:

```swift
private var map: [Key: Node] = [:]
private var head: Node?     // most recently used
private var tail: Node?     // least recently used
```

Why **doubly**-linked: to remove a node in O(1) you need its predecessor. With a singly-linked list, removal is O(n) and the whole design collapses.

```swift
public func get(_ key: Key) -> Value? {
    guard let node = map[key] else { return nil }
    moveToFront(node)           // ← the "recently used" part of LRU
    return node.value
}
```
Forgetting `moveToFront` in `get` is the single most common bug — the cache then evicts by insertion order, which is FIFO, not LRU.

### Memory note
`Node` holds strong `prev`/`next` references, so the list is a retain cycle by construction. It's fine here because the cache owns the whole list and `remove` clears both pointers on eviction — but be ready to say it. In a design where nodes outlive the cache, one direction must be `weak`.

### Extension questions
1. Make it LFU (least *frequently* used). What changes? (A frequency bucket list — genuinely harder.)
2. Add a TTL per entry. Where does expiry get checked — on read, or by a sweeper?
3. Make it thread-safe without serialising every read. (Module 09 §2, reader-writer.)
4. What if values are expensive and you want to avoid two concurrent loads of the same key? (Task coalescing — Module 09 E6.)

---

# SOLVED 6 — HashMap

### Requirements
Implement `put`, `get`, `remove` from first principles, with collision handling and resizing.

### The design
Separate chaining: an array of buckets, each holding a small array of entries.

```swift
private var buckets: [[Entry]]

private func index(for key: Key, in size: Int) -> Int {
    var hasher = Hasher()
    hasher.combine(key)
    return abs(hasher.finalize() % size)
}
```

The three things being assessed:
1. **Collisions** — two keys landing in the same bucket must both survive. Chaining handles it; the linear scan inside a bucket is O(1) on average because buckets stay short.
2. **Update vs insert** — `put` on an existing key must replace, not append, and must not increment `count`.
3. **Load factor and resize** — when `count / capacity > 0.75`, double the capacity and **rehash every entry**. Copying buckets without rehashing is the classic bug: indices depend on capacity, so entries become unfindable.

```swift
if Double(count) / Double(buckets.count) > loadFactor { resize() }
```

### Tradeoff to state
Chaining vs open addressing (linear probing). Chaining is simpler and degrades gracefully; open addressing has better cache locality and no per-bucket allocation, but needs tombstones on delete. Swift's own `Dictionary` uses open addressing.

### Extension questions
1. Implement `remove` correctly under open addressing. (Why tombstones exist.)
2. What happens if `Key`'s `hashValue` is constant? (Every operation becomes O(n) — a hash-flooding DoS; Swift seeds its hasher per process for this reason.)
3. Add `keys`, `values` and `Sequence` conformance. (Module 07 §7.)

---

# SOLVED 7 — Trie

### Requirements
Insert words, check membership, check prefixes, and list all words with a prefix.

### The design
A node per character, with a dictionary of children and an `isWord` flag.

```swift
private final class Node {
    var children: [Character: Node] = [:]
    var isWord = false
}
```
The `isWord` flag is the subtlety: without it you can't distinguish `"car"` (a word) from `"car"` as a prefix of `"cart"`. `contains` checks the flag; `hasPrefix` only checks that the path exists.

```swift
public func words(withPrefix prefix: String) -> [String] {
    guard let start = node(for: prefix) else { return [] }
    var out: [String] = []
    collect(start, current: prefix, into: &out)
    return out.sorted()
}
```
Walk to the prefix node once, then DFS. Complexity: O(len(prefix) + size of subtree) — versus O(total characters) for scanning a word list, which is why tries exist.

### Extension questions
1. Rank suggestions by frequency. (That's solo problem 4.)
2. Support wildcards (`c.r` matches `car`). (Branch on `.` across all children.)
3. Memory: a trie over a large dictionary is heavy. What compresses it? (Radix tree / DAWG.)
4. Delete a word. (Unset `isWord`, then prune leaf nodes bottom-up — harder than insert, and a good follow-up.)

---

# Cross-problem lessons

| Lesson | Where it showed up |
|---|---|
| Two nouns are often one concept | snake/ladder → `Jump` |
| Inject randomness and time | `Dice`, and `Clock` in Module 02 |
| Validate-then-mutate | Tic-Tac-Toe, Connect Four, vending machine |
| A new action invalidates the alternate history | browser forward stack, redo stack |
| Pick the data structure from the *access pattern* | LRU needs dict + linked list |
| Store the derived value if recomputing is O(n) | min-stack's running minimum |
| A flag distinguishes "path exists" from "word exists" | trie's `isWord` |
| No pattern is a valid design | Tic-Tac-Toe, min stack, trie |

---

## ✅ Checkpoint
1. Why is the win check O(N) and not O(N²)?
2. Why must `get` reorder the LRU list, and what does the cache become if it doesn't?
3. Why does a HashMap resize have to rehash rather than copy?
4. What does a trie's `isWord` flag distinguish?
5. Name two problems here where injecting a dependency made the design testable.

Then: `EXERCISES.md` (5 solo problems) → `swift test --filter M11` → `SOLUTIONS.md` → `PROJECT.md`.
