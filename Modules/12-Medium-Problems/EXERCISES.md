# Module 12 — Solo Problems

Five medium designs in [`Code/Exercises.swift`](Code/Exercises.swift). Run `swift test --filter M12`. Time-box each to 60 minutes.

### SOLO 1 — LFU Cache
Evict the least *frequently* used entry; break ties by least recently used. Both `get` and `put` count as uses, and `put` on an existing key counts too.
*Design point:* you need two orderings at once (frequency, then recency). The simple version stores both per entry and scans on eviction — O(n) per eviction. The O(1) version keeps a doubly-linked list per frequency bucket. **Write the simple one, then say the complexity out loud.**

### SOLO 2 — Coupon Engine
Three coupon types with different rules, one applicable coupon per order (biggest discount, ties by code). The grader defines a coupon type the engine has never seen.
*Design point:* a `Coupon` returning `Decimal?` means "doesn't apply" and "applies for zero" stay distinguishable — a small API decision with real consequences.

### SOLO 3 — In-Memory File System
`mkdir -p`, write, read, `ls`, and recursive `size`.
*Design point:* one `Node` type where `children != nil` means directory is the **Composite** pattern (Module 06 §3). `size` recurses; the leaf reports its own bytes. Watch the error taxonomy — `notFound`, `notADirectory`, `notAFile` and `alreadyExists` are four different failures and the grader checks all four.

### SOLO 4 — Job Scheduler with Dependencies
Topological order, respecting dependencies; among *currently runnable* jobs, highest priority first, ties by name.
*Design point:* priority must never override a dependency — the grader has a priority-100 job that must still wait for a priority-1 one. Detect cycles ("work remains but nothing is runnable") and report unknown dependencies separately.

### SOLO 5 — Meeting Rooms
Minimum rooms for a set of meetings, plus an assignment, plus a per-room calendar that rejects overlaps.
*Design point:* `end` is exclusive, so back-to-back meetings share a room. `minimumRooms` is a sweep line over sorted starts and ends; if you sort meetings and scan pairwise, you'll get it wrong for three-way overlaps.

## Stretch (not graded)
1. Make the LFU cache genuinely O(1). Sketch the frequency-bucket structure before coding — it's the real interview follow-up.
2. Allow two coupons to stack, with an ordering rule. What breaks in `bestCoupon`, and what does the API become?
3. Add `mv` and `rm -r` to the file system. Which one is harder and why?
4. Give the scheduler concurrent execution with a worker pool. Which module covers the hazards?
5. Add recurring meetings ("every Tuesday for 8 weeks") to the room calendar. Does `Meeting` change, or do you need a new type?
