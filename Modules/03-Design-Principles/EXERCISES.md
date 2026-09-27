# Module 03 — Exercises

Fill in [`Code/Exercises.swift`](Code/Exercises.swift). Run `swift test --filter M03`.

### E1 — DRY: one home for a rule
The username rule must exist in exactly one place: `Username.init?`. `SignupForm` and `AdminImporter` consume it. If you write `raw.count >= 3` twice, you've failed the exercise even if tests pass — check yourself.

### E2 — KISS: convert temperatures
Three scales, nine directed pairs. Write the simplest correct thing. **Hint:** normalising through one pivot scale turns 9 cases into 3 + 3. Resist building a `ConverterFactory`.

### E3 — Demeter: kill the train wreck
Implement one forwarding accessor per level so `Shipment` reaches no further than its own `customer`. Notice how small each method is — that's the point, and also the cost.

### E4 — Tell-Don't-Ask + Information Expert
`CartItem` knows its subtotal; `Cart` knows its total; `Cart` decides shipping. The caller never reads `total` and branches. `add` merges by sku keeping the first unit price (a real product rule you'd have to ask about).

### E5 — Encapsulate what varies
Password rules vary; policy evaluation doesn't. Put each rule in its own type behind `PasswordRule`. The grader defines a new rule inside the test — your `PasswordPolicy` must not need editing.

### E6 — Classification
Map each situation to the principle. Pure recall.

## Stretch (not graded)
1. In E1, the product now wants underscores allowed for legacy imports only. Where does that go — and does it break DRY to special-case it?
2. In E4, add a "buy 3 get 1 free" rule. Does it belong on `CartItem`, `Cart`, or a new type? Justify with Information Expert *and* Pure Fabrication.
3. In E5, add a rule that needs the *username* to reject "password contains your name". What must change in the protocol, and what does that tell you about choosing a protocol's input shape?
4. Find two pieces of duplicated code in your day-job repo: one you should extract, one you shouldn't. Write down the test you used to tell them apart.
