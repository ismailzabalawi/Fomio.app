# Native TextField audit reference

Isolated diagnostic project, built outside Fomio at `/private/tmp/fomio-search-field-reference`. Run8ae140ce on iPhone17/iOS27.0 has **two failing `.textClipped` audits** with the identical report to Fomio: “Text of this SwiftUI.UIKitTextField may be clipped at larger Dynamic Type sizes.”

One view uses only `TextField(...).font(.body)` inside an unconstrained VStack. The second adds `.frame(minHeight:44)`. Neither includes Fomio navigation, theme, search state, safe-area header, AnyLayout, font override or fixed parent height. The standard-size capture is inspected and its complete Adaptive value is visible. This reproduces the predictive warning without Fomio layout; it does not prove every app control or accessibility size is correct, and does not turn either failed audit into a pass. Fomio's separate actual-system AX5 and in-place font/focus tests remain the functional evidence.

Sources are stored as `.txt` to keep them outside app targets. To reproduce in a disposable folder, restore `App/ReferenceApp.swift`, `UITests/ReferenceUITests.swift` and `project.yml` from these files, run `xcodegen generate`, then test SearchFieldReference on the recorded simulator/runtime. No Fomio project regeneration occurred. The reference uses a separate bundle identifier and derived-data folder. Native Fomio tool settings were restored in the explicit `fomio-native` profile afterward; the original default profile was left untouched.

[Summary](summary.json), [bare issue](bare-field-issue.txt), [minimum-height issue](minimum-height-field-issue.txt), [capture](bare-field.png), [hierarchy](bare-field-hierarchy.txt).
