// swift-tools-version: 6.0
import PackageDescription

// One target pair per module that has code. Modules 04 (UML) and 15 (mocks) are
// documentation-only, so they have no target.
//
//   swift test                 run every module's grader
//   swift test --filter M07    grade one module
//
// Each module's `Code/` folder is the target; `Solutions/` is deliberately NOT
// compiled, so the reference answers can't leak into your build.

let modules: [(id: String, path: String)] = [
    ("M01", "01-OOP-Fundamentals"),
    ("M02", "02-SOLID-Principles"),
    ("M03", "03-Design-Principles"),
    ("M05", "05-Creational-Patterns"),
    ("M06", "06-Structural-Patterns"),
    ("M07", "07-Behavioral-Patterns"),
    ("M08", "08-Choosing-The-Right-Pattern"),
    ("M09", "09-Concurrency-For-LLD"),
    ("M10", "10-LLD-Problem-Framework"),
    ("M11", "11-Easy-Problems"),
    ("M12", "12-Medium-Problems"),
    ("M13", "13-Hard-Problems"),
    ("M14", "14-LLD-For-iOS"),
]

let package = Package(
    name: "LLDMastery",
    platforms: [.macOS(.v13)],
    targets: modules.flatMap { module in
        [
            Target.target(name: module.id, path: "Modules/\(module.path)/Code"),
            Target.testTarget(name: "\(module.id)Tests",
                              dependencies: [.target(name: module.id)],
                              path: "Modules/\(module.path)/Tests"),
        ]
    }
)
