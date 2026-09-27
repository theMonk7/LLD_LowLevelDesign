# Module 11 — Solo Solutions & Commentary

Reference code: [`Solutions/ExercisesSolution.swift`](Solutions/ExercisesSolution.swift).
Solved-problem code: [`Solutions/Solved.swift`](Solutions/Solved.swift).

## SOLO 1 — Deck
```swift
public func reset() {
    cards = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(rank: $0, suit: suit) } }
}
public func shuffle() {
    guard cards.count > 1 else { return }
    for i in stride(from: cards.count - 1, through: 1, by: -1) {
        cards.swapAt(i, rng(i + 1))
    }
}
public func deal() -> Card? { cards.popLast() }
```
Three decisions worth noting:

**`popLast()` rather than `removeFirst()`.** Removing from the front of an array is O(n); the top of the deck is the end of the array. The physical metaphor ("top of the deck") and the efficient implementation happen to agree — but only because you chose the representation deliberately.

**Injected `rng`.** `rng(n)` returns a value in `0..<n`, which is exactly what Fisher-Yates needs. The identity generator `{ $0 - 1 }` makes every swap a no-op, so the grader can assert the deck is unchanged — you can't test a shuffle without controlling the randomness.

**`reset()` called from `init`.** One code path builds the deck, so "fresh deck" and "reset deck" can never drift apart (DRY, Module 03 §1).

The common bug is a shuffle that calls `rng(count)` every iteration instead of `rng(i + 1)`. That's "naive shuffle" and it's **biased** — it doesn't produce all permutations with equal probability. Knowing why Fisher-Yates walks downward is worth a sentence in an interview.

## SOLO 2 — Connect Four
```swift
guard let row = grid[column].firstIndex(where: { $0 == nil }) else { throw .columnFull }
```
Gravity in one line: the disc lands in the lowest empty row. Storing `grid[column][row]` (column-major) rather than `grid[row][column]` makes this natural — the representation follows the access pattern.

```swift
let directions = [(1, 0), (0, 1), (1, 1), (1, -1)]
for (dc, dr) in directions {
    var total = 1
    total += run(disc, from: (column, row), step: (dc, dr))
    total += run(disc, from: (column, row), step: (-dc, -dr))
    if total >= 4 { return true }
}
```
Four directions, each counted **both ways** from the new disc, so a disc dropped into the middle of a run is detected. Eight separate direction checks would double the code; scanning the whole board would be 42 cells per move instead of at most 12.

**Error precedence** is specified, and that's the lesson: `gameOver` before `notYourTurn` before bounds before `columnFull` is a *product* ordering, not an obvious one. In an interview, ask; in life, write it down.

`placed == rows * columns` detects the draw in O(1) instead of scanning for empties.

## SOLO 3 — Ring Buffer
```swift
public mutating func enqueue(_ element: Element) throws {
    guard !isFull else { throw RingBufferError.full }
    storage[tail] = element
    tail = (tail + 1) % capacity
    count += 1
}
public var elements: [Element] {
    (0..<count).compactMap { storage[(head + $0) % capacity] }
}
```
`count` exists because `head == tail` is ambiguous: it's true both when the buffer is empty and when it's full. The alternatives are keeping a `count` (chosen here — clearest) or wasting one slot so full is `(tail + 1) % capacity == head`. Both are standard; naming the ambiguity is the interview point.

`elements` walking `(head + i) % capacity` is what makes the wrap-around test pass. The bug that test catches is returning `storage.compactMap { $0 }`, which gives you storage order rather than queue order after a wrap.

`enqueueOverwriting` reuses `dequeue` and `enqueue` rather than duplicating index arithmetic — one place where the modular arithmetic can be wrong instead of three.

## SOLO 4 — Autocomplete
```swift
var frequency: Int?          // non-nil marks a complete word
...
if node.frequency == nil { distinctWords += 1 }
node.frequency = frequency
```
A single optional does the job of the trie's `isWord` flag **and** the ranking data. Re-inserting replaces the frequency without inflating the word count — the test exists because that's the easy bug.

```swift
return found
    .sorted { $0.frequency != $1.frequency ? $0.frequency > $1.frequency : $0.word < $1.word }
    .prefix(limit)
    .map(\.word)
```
An explicit tie-break makes the result deterministic. "Sort by frequency" alone gives you an unstable order between equal-frequency words, which produces a UI that reshuffles between keystrokes — a real bug that starts as a missing comparator.

**Collect-then-sort vs sorted-at-insert:** this collects the whole subtree and sorts, which is O(m log m) per query. For a search box over a large dictionary you'd instead cache the top-k at each node during insert, trading memory and write cost for O(k) reads. Right answer depends on read/write ratio — say which you'd pick and why.

## SOLO 5 — Leaderboard
```swift
private func ranked() -> [(key: String, value: Int)] {
    scores.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
}
```
One comparator, used by both `top` and `rank`, so the two can never disagree. Duplicating the sort in both methods is how "you're rank 4" ends up inconsistent with a leaderboard that shows you third.

`addScore` uses `scores[playerID, default: 0] += delta`, which creates the player on first use — Swift's subscript default making "upsert" a single line.

`reset` deliberately keeps the player at 0 rather than removing them, because "still on the board with 0" and "not on the board" are different states — and the test asserts `playerCount` stays 3.

**Complexity, honestly:** every query is O(n log n). Fine for a few thousand players; wrong for a million. At scale: a max-heap for `top(k)`, or a score-bucketed skip list / order-statistics tree for `rank`. Saying *"I'd sort now and move to a heap when n grows, and here's the interface that lets me swap it"* is the correct answer — premature optimisation is also a failure mode.

## Self-check
| If you… | Re-read |
|---|---|
| called `Int.random` inside `Deck` | SOLO 1 — inject randomness |
| shuffled with `rng(count)` each iteration | SOLO 1 — Fisher-Yates bias |
| scanned the whole board for a win | SOLO 2 |
| used `head == tail` to mean empty | SOLO 3 |
| forgot the alphabetical tie-break | SOLO 4 |
| wrote two different sort comparators | SOLO 5 |
