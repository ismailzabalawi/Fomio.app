# Minimal semantic Dynamic Type diagnostic

Separate temporary project `/private/tmp/fomio-dynamic-type-reference`, distinct bundle `com.fomio.dynamictypereference`, iPhone17/iOS27.0. No Fomio layout, navigation, environment override, fixed heights or state is included.

`105ebaf1`: one Dynamic Type audit passes plain semantic headline/subheadline/button. The native `ContentUnavailableView` with `.font(.body)` description fails the same predictive report as Fomio: “User will not be able to change the font size of this SwiftUI.AccessibilityNode.” [Summary](audit-summary.json), [exact native issue](native-placeholder-audit.txt).

`da0eca77`: actual native system Large→AX5→Large growth test **passes**. Description frame grows from313×22.33pt to517.33×136.67pt and returns to its baseline height. The official `simctl ui content_size` command changes only this test device at logged checkpoints; the original `large` setting is restored and queried. The default sandbox blocked the watcher’s CoreSimulator connection; the same scoped watcher succeeded through approved escalation. [Summary](native-system-growth-summary.json), [geometry](native-system-growth.txt), [readbacks](system-font-events.json), [AX5 capture](native-system-ax5.png).

This establishes that the minimal native placeholder's audit report contradicts measured system-size growth. It does not make a failed audit pass, explain every Fomio element, or prove all accessibility behavior. Fomio's separate actual iPad growth test covers its scoped selector/empty-state heading. Original failure evidence remains preserved.

Source snapshots are text files outside app targets: [app](ReferenceApp.swift.txt), [tests](ReferenceUITests.swift.txt), [project](project.yml.txt). Restore them into a disposable project and run XcodeGen there to reproduce. The Fomio project was not regenerated. Later native Settings navigation probes are test-only diagnostic methods in this snapshot; they did not alter VoiceOver.
