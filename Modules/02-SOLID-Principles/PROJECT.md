# Module 02 Project — Refactor a Rotten `ReportGenerator`

**Time:** 2–3 hours. This is the *refactor round* format, which appears in real interviews more often than greenfield design.

## The code to fix

Create `RottenReportGenerator.swift` with exactly this, then fix it. (Typing it yourself matters — you'll spot smells as you type.)

```swift
import Foundation

final class ReportGenerator {
    var format: String = "pdf"          // "pdf" | "csv" | "html"
    var includeCharts = true
    static let shared = ReportGenerator()

    func generate(userID: String) -> Data {
        // 1. fetch
        let url = URL(string: "https://api.example.com/users/\(userID)/metrics")!
        let raw = try! Data(contentsOf: url)
        let json = try! JSONSerialization.jsonObject(with: raw) as! [String: Any]

        // 2. compute
        let values = json["values"] as! [Double]
        let avg = values.reduce(0, +) / Double(values.count)
        let max = values.max() ?? 0

        // 3. format
        var body = ""
        switch format {
        case "pdf":  body = "PDF avg=\(avg) max=\(max)"
        case "csv":  body = "avg,max\n\(avg),\(max)"
        case "html": body = "<html>avg=\(avg) max=\(max)</html>"
        default:     body = ""
        }
        if includeCharts && format != "csv" { body += " [chart]" }

        // 4. stamp + persist + notify
        body += " generated \(Date())"
        try! body.write(toFile: "/tmp/report-\(userID).txt", atomically: true, encoding: .utf8)
        print("emailing report to \(userID)")
        return Data(body.utf8)
    }
}
```

## Task

1. **Write the smell list first** — in comments, name every violation and which principle it breaks. There are at least ten. Aim for ten before you change a line.
2. Refactor to SOLID. Every behaviour above must survive.
3. Make it fully unit-testable with **no network, no disk, no real clock, no singleton**.
4. Write tests: one per formatter, one for the averaging, one proving the generator never touches the network.
5. Add a **fourth format (`markdown`) without editing any existing type.** If you can't, OCP isn't done.

## Required end state (checklist)

- [ ] Data fetching behind a protocol (`MetricsFetching`) — injected
- [ ] Computation in its own pure type (`MetricsSummariser`)
- [ ] One formatter type per format, conforming to one protocol; registry or injection chooses
- [ ] Charts handled without `if format != "csv"` buried in the formatter chain
- [ ] `Clock` protocol injected; no `Date()` in domain code
- [ ] Persistence behind a protocol; `/tmp` path gone from the domain
- [ ] Notification behind a protocol
- [ ] No `static let shared`
- [ ] No `try!`, no `as!`; errors modelled and propagated
- [ ] Adding `markdown` = one new file, zero edits

## Rubric (/50)

| Criterion | 0 | 3 | 5 |
|---|---|---|---|
| Smell list written before refactoring | none | partial | 10+ named with principles |
| SRP: one responsibility per type | god class remains | partial split | clean split by actor |
| OCP: new format without edits | switch remains | switch moved | genuine open extension |
| LSP: no conformer throws "unsupported" | violated | partial | clean |
| ISP: narrow protocols | one fat protocol | partial | role protocols |
| DIP: all I/O injected | none | some | network, disk, clock, mail all injected |
| Error handling | `try!` survives | some | typed errors, propagated |
| Tests | none | happy path | all formats + failure paths |
| No hidden globals | singleton remains | — | removed, construction explicit |
| Naming | `Manager`/`Helper` | mixed | every name states a responsibility |

**40+/50** → Module 03. Below 30 → redo after re-reading the smell table.

## Extension questions
1. The API now returns paginated metrics. Which type changes? (Should be exactly one.)
2. Product wants reports generated on a schedule. Where does that live — and why not in `ReportGenerator`?
3. You must support a customer-specific PDF layout. Strategy, Template Method, or Decorator? Defend your pick (revisit after Module 08).
4. Your refactor added 8 types where there was 1. Argue the case *against* your own refactor for a codebase that will never add a second format.

Ask me to review your refactor against this rubric when done.
