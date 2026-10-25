# Final fixes review — 2026-10-19

Claude finished and committed the two fixes locally as `4f5225620552a3fcd839076514372773ca893182` on `claude/fomio-release-integration`. The integration worktree is clean. Its local `origin/main` still points to `eef6b2f`; the Claude session explicitly says no subsequent push/upload and asks whether to push. This audit did not push, upload, modify implementation or send another instruction to Claude.

## Both requested fixes verified

Reviewed the production changes, fixture suspension hook and all four new regression tests. No new blocking defect found within these two fixes.

- Refresh race: confirmed-read revisions protect stale incoming rows, and overlapping Unread refreshes fetch again before reconciling their cursor. Tests suspend the response after its snapshot, acknowledge, then deliver that response. Coverage includes Unread refresh, All refresh and an All page response; tests verify every remaining unread ID appears without gaps.
- Grouped Ignore filtering: `filterNames` is empty when no single actor can be credited. Tests cover a grouped bucket, collapsed reply, fixture bucket whose original member is ignored, and an individual notification that must remain hidden.

Independently recompiled the unchanged saved `probes/Race.swift` against the final production `Notifications.swift` and `NotificationStore.swift`, using the saved minimal dependencies/fixture. Actual output:

```text
After successful acknowledgment: ["7:false"]
After older refresh completes: ["7:false", "6:false"] next: Optional(2)
Next page IDs: [7, 6, 5, 4] server ID8 read: true
Grouped actor: nil hidden by ignoring original member: false
```

The stale row does not return, ID 6 is retained, and ignoring the original member no longer hides the group. This probe runs the store/model logic rather than a simulator UI. It makes no live requests or writes.

## Final test results verified from raw logs

Integration worktree `.build/final-complete.log` records an unfiltered `xcodebuild ... test` on Fomio Release iPhone 17, iOS 27.0, simulator `CAB241D5-6903-45BC-91E8-FDECC89F6D78`:

| Target | Executed | Passed | Skipped | Failed |
| --- | ---: | ---: | ---: | ---: |
| Unit/contract | 133 | 129 | 4 | 0 |
| UI | 50 | 45 | 3 | 2 |
| Total | 183 | 174 | 7 | 2 |

All 27 notification unit tests passed, including all four new regressions. All ten notification UI tests passed. Overall result is **TEST FAILED**, not a clean full-suite pass. Result bundle: `.build/final-complete.xcresult`.

The two failures are:

1. `FeedAppearanceUITests.testDarkAccessibilityTextAndRightToLeftCaptures`, `FeedAppearanceUITests.swift:159`: Compact menu item absent. The log shows a 32-second idle wait after tapping Feed options. That is evidence of a stall, but does not alone prove why the menu was absent or rule out an app interaction defect.
2. `FomioUITests.testSwipeDismissalProtectsChangedWriting`, `FomioUITests.swift:318`: keyboard remained present after Hide keyboard. The helper still calls `toggle.tap()` directly; a moving-control race is plausible from earlier evidence, but the latest run does not directly measure a missed tap or establish the cause.

`.build/rerun2.log` confirms three repetitions of each failing test with `test-without-building` on the same simulator and derived build: six executions, six passed, zero skipped/failed. Result bundle: `.build/rerun2.xcresult`. These reruns establish intermittency, not a proved root cause or a successful final complete-suite run. No test assertion or helper was changed by the fix commit.

## Recommendation

Accept the two notification corrections as verified. Keep the release hold: investigate/stabilize the two outstanding UI failures with evidence, then obtain a clean complete-suite run on the final code and record it before another push/upload. The existing passing targeted reruns should remain documented separately. Full simulator tests were not independently repeated by this audit; the unchanged independent probe was.

The marketing-version decision and existing live push/device acceptance limitations are still separate release gates. No marketing version was chosen by this review.
