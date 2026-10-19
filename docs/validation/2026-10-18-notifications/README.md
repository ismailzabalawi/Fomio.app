# Notifications validation — 2026-10-18

Branch `claude/fomio-notifications`, worktree `.claude/worktrees/fomio-notifications`, based on `b62aef5` with the uncommitted build 0.8.0 (7) working tree staged as the baseline (notification work is unstaged on top). Nothing committed, merged, pushed or uploaded. Backend reference `/Volumes/Develop/Projects/Dicourse` read only, HEAD `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2` (rechecked). No live Discourse request, notification write, settings change or push was made.

Environment: Xcode 27.1 (27A9275), iOS 27.0 simulator runtime (24A434). The iOS 26.1/26.2 runtime images disappeared from the host during this work; earlier iOS 26.1 runs are noted where used. Dedicated simulators: Fomio Notif iPhone 17, iPhone SE (3rd gen), iPad Pro 11-inch (M5), plus a "Baseline iPhone 17" for comparison runs. The host was heavily loaded by concurrent sessions (load average peaked above 900), which lengthened runs.

## Final results

Complete suite after all fixes (`.build/final-full.xcresult`, iPhone 17 / iOS 27.0, one run): **179 tests — 171 passed, 7 skipped (4 opt-in live checks, 3 existing UI skips), 1 failed.** Unit/contract: 129 executed, 4 skipped, 0 failures (23 notification tests, including 5 audit regressions and 2 expired-key tests; 1 new feed-geometry test). UI: 50 executed, 3 skipped, 1 failure (`testNativeBlockFormAndMarkdownRoundTrip`, see below); all 11 notification UI journeys and all 8 previously failing tests passed.

Targeted evidence: all eight earlier failures plus all notification UI tests passed together (`.build/fix-ui-1.xcresult`), except the two feed tests, which then passed with the feed fixes (`.build/fix-feed2.xcresult`, 13 tests: 12 passed; `testSwitchKeepsPaginationErrorAndLoadedPages` was ended by SIGTERM during that heavily loaded run, with no Fomio crash report, and passed alone in `.build/fix-pag.xcresult`). Notification unit suite: 23/23 (`.build/audit-unit-3.xcresult`, full unit run 128/128 before the geometry test was added).

### Remaining UI failure — `testNativeBlockFormAndMarkdownRoundTrip`

After the pushed code-block form closes, the composer's floating bar stays at the bottom safe area (y 784) behind the keyboard (top 590) instead of rising with it (frames now included in the assertion message). It passed in the earlier full run, then failed 3/3 on the same simulator. Cross-checks isolate it from this branch:

| Build | Baseline iPhone 17 simulator | Fomio Notif iPhone 17 | New “Fresh” iPhone 17 |
| --- | --- | --- | --- |
| Untouched baseline (no notification code) | passed 2/2 | failed 1/1 | failed 2/2 |
| Notifications branch | passed 2/2 | failed 3/3 (+2 with an experimental change, reverted) | failed 2/2 |

The result follows the simulator, not the code, so it is not caused by notification changes. The root cause inside the composer (keyboard safe-area propagation after a pushed form on iOS 27, depending on device state) is not established; it is a composer issue to investigate separately. An experimental change (replacing the composer's pending-notification `safeAreaInset` with an overlay) did not change the result and was reverted.

## Independent audit findings — fixed

[Audit](independent-audit.md) and [probes](audit-probes/). All four are corrected with regression tests in `FomioTests/NotificationTests.swift` (“Independent audit regressions”). Re-running the auditor's unchanged probes against the fixed store:

```text
Unread after acknowledgment: ["7:read=false"]
Unread after next page: [7, 6, 5] ; expected next unread ID 6, found: true
After successful refresh removes access to all targets: [] ; refreshError: nil
Recheck inaccessible unread row: server.read= false ; client.read= Optional(false) ; outcome= Optional(probe.AcknowledgmentState.unknown)
```

| # | Fix (`Fomio/…`) | Regression test |
| --- | --- | --- |
| 1 | `NotificationStore.confirmRead` removes a confirmed row from the Unread feed and lowers its raw `nextOffset` by one (Discourse filters `read: false` before `offset`); applies to acknowledgments from All or Unread and to rechecks. A per-filter cursor epoch discards an Unread page that was in flight when the cursor shifted and restarts that feed | `testAuditAcknowledgmentLeavesUnreadAndKeepsCursorAligned` (Unread and All, partial loads), `testAuditAcknowledgmentDuringInFlightUnreadPageRestartsWithoutGap` |
| 2 | `refresh()` restarts the feed from the authoritative first window when no returned ID overlaps loaded rows (empty/inaccessible window, fully replaced window); rows no feed references leave memory with their titles; the other filter restarts, including an in-flight page | `testAuditRefreshWithoutOverlapRestartsAndDropsRestrictedRows` |
| 3 | `recheck` scans All history for the row: returned read → confirmed; returned unread → failed; not found → stays unknown. Absence never confirms | `testAuditRecheckRequiresPositiveEvidence` |
| 4 | `DiscussionState.requiredContentReady` requires, for grouped `thread` routes, the parent's child replies loaded without error; `AppState.displayed` uses it and `DiscussionView` re-checks when it flips (Retry replies) | `testAuditGroupedRepliesAcknowledgeOnlyAfterRepliesLoad` (parent loads, children offline → unread and pending; retry → acknowledged) |

## Expired-key notification tap

Source: a revoked/expired user API key makes `DefaultCurrentUserProvider` raise `Discourse::InvalidAccess`, which `ApplicationController` renders as **403 `invalid_access`** for every request carrying the key (never 401). The tap path now calls `credentialIsValid` (`GET session/current.json`; 403/401/404 or another username ⇒ invalid) before routing; an invalid key keeps the intent, shows “Sign in to open this notification”, fetches no protected content, and after signing in as the same member opens the target without acknowledging it early. Tests: `testExpiredKeyTapKeepsIntentAndRoutesAfterSignIn`, `testLiveCredentialCheckTreatsInvalidAccessAsExpired` (stubbed 403), UI `testExpiredKeyPushTapAsksToSignInThenOpensTarget` (fixture preset `notif-push-expired`). Remaining gap: other screens still show such a 403 as “You don’t have permission”; the deployed 403 response was not exercised.

## The eight earlier UI failures

The earlier full run (`.build/notif-full-27.log`, `.build/notif-full-27.xcresult`) executed 121 unit tests (4 skipped, 0 failures) and 49 UI tests (3 skipped, 8 failures). Each was investigated with failure hierarchies, a comparison build of the untouched baseline (no notification code) on an identical iOS 27 simulator, and temporary probe tests whose recorded facts are saved in [ui-root-cause/](ui-root-cause/). The probes were removed afterwards.

| Test | Baseline (no notification code) | Root cause (evidence) | Fix |
| --- | --- | --- | --- |
| `FeedAppearanceUITests.testCardCasesOmitAbsentFieldsAndKeepSeparateTargets` | Fails identically | iOS 27 AsyncImage stayed in its loading phase for failing URLs: after 6 s the failed-media card still read “Loading image … Has image” (`label-after-6s.txt`); a refused loopback HTTPS URL also never failed within 10 s. The text fallback never ran. The test also asserted immediately after scrolling | App: `TopicMedia` loads remote media with an explicit request and sets the failure state on error/non-2xx (cancellation excluded). Fixture: failing URL is a refused loopback HTTPS address instead of a `file:` URL. Test: waits up to 10 s for the fallback label (same assertion) |
| `FeedAppearanceUITests.testSwitchKeepsMidFeedTopicAnchorBothDirections` | Fails identically | The `.scrollView` coordinate space origin moved under the navigation bar on iOS 27, so a card hidden behind the bar was chosen as the reading anchor. Instrumented run: scroll-view global frame + safe-area inset gave a visible top of 232, while a marker in the scroll view's safe area and the `scrollTo(.top)` result both measured 116 | App: `FeedGeometry` reads card frames and the visible region in global space, the region from top/bottom markers inside the scroll view's safe area |
| `FomioUITests.testLargestTextSelectionFitsBar` | Fails identically | At AX XXXL the body field spans y 788–988 on the 874-pt window (failure hierarchy), so XCUI's centre tap lands off-screen and focus never arrives | Test: taps the field's visible top edge and waits for the keyboard; all later assertions unchanged |
| `testFailedPhotoKeepWarnsAndResumeRetainsWriting`, `testNativeFormattingCaretTypingSurvivesSourceSwitch`, `testVisualChecklistCanBeCreatedAndCheckedWithoutSource`, `testVisualDraftRecoversAfterTerminationWithExactMarkdown`, `testVisualHeadingMarkdownPreviewAndReturnPreserveDraft` | Passed once; intermittent on the notifications build too (heading failed again in a rerun) | Floating composer bar still moving with the keyboard when tapped. Probe: right after typing, “Heading 2” was at y 784 and at y 490 0.38 s later (`turn-into-frames.txt`); failure hierarchies show the Turn-into strip still open with Paragraph selected, or the More menu never opened (photo test line 429 was `Sample photo` existence) | Test: `tapSettled` waits until the control's frame stops changing before tapping bar controls (`composer-block-type`, Turn-into options, `composer-more`); `chooseTurnInto` additionally asserts the strip closed |

None of the eight was caused by notification code: three fail on the untouched baseline under iOS 27, and the five intermittent ones share the bar-motion race present in the baseline tests.

## Native visual evidence

Captures in this folder (fixtures, labelled fictional): `iphone17-inbox-light.png` (inbox, badge 6 from server totals), `iphone17-consolidated-replacement.png` (5010 replaced by 5020 “4 new replies”, no duplicate), `iphonese3-ax2-dark.png` (375 pt, AX2, dark: full native tab labels), `iphone17-settings-off.png`, `ipad-settings-wording.png` (“This iPad”). iOS 27 has no 320-pt device; 375 pt is the narrowest simulator. These are screenshots, not full interactive accessibility acceptance.

## Remaining gates

- Live Discourse: ordinary-member history/filter/mark-read/totals with the deployed type mix, grouped payloads and the deployed 403 response for revoked keys.
- MessageBus wire protocol (gem source unavailable) — realtime disabled; refresh on foreground/reconnect/manual only.
- Push: no relay, enrollment API, APNs credentials, entitlement or `push_url` authorization exists; live Settings show “Not available yet”. Fixture prompts, enrollment and taps are simulations and prove no delivery. Tap payloads would need a notification ID to acknowledge from a push.
- Unsupported rows without a destination have no dismissal (proposal in the design handoff).
- Device acceptance: VoiceOver order/announcements, every Dynamic Type size, RTL, external keyboard, iPad resizing and physical-device push.


## Integration and second audit — 2026-10-19

Integrated on `claude/fomio-release-integration` and pushed to `main` as `e3a6e04` (build 7 baseline over build 6), `afeea60` (notifications), `eef6b2f` (composer transition fix). A selected pre-push run passed (152 tests: 148 passed, 4 skipped). Uploading 0.8.0 (8) was rejected by App Store Connect because the 0.8.0 train is closed (previously approved); nothing was uploaded. Release is on hold pending these fixes and a marketing-version decision.

[Second independent audit](../2026-10-19-independent-audit/README.md) (on `eef6b2f`) found two P2 issues, fixed in follow-up commits:

| Finding | Fix | Regression tests (`FomioTests/NotificationTests.swift`) |
| --- | --- | --- |
| Refresh snapshot taken before an acknowledgment restored the read row in Unread and the stale offset skipped ID 6 | `NotificationStore` keeps a confirmation revision. An Unread refresh that overlapped a confirmed read or cursor change fetches again (up to three times, then restarts the feed); any snapshot older than a confirmed read cannot mark it unread (refresh, page loads and rechecks) | `testAudit2StaleUnreadRefreshCannotRestoreAcknowledgedRow`, `testAudit2StaleAllRefreshKeepsConfirmedReadAndUnreadStaysAligned`, `testAudit2StaleAllPageCannotDowngradeConfirmedRead` (fixture `suspendNextHistory` holds a response after its snapshot, as in the audit harness) |
| Ignoring a grouped row's `original_username` hid replies from other members | `NotificationItem.filterNames` is empty unless the row is credited to one member (`actor != nil`), so grouped and collapsed reply rows are never filtered by one name | `testAudit2GroupedRowSurvivesIgnoringItsOriginalMember` (mixed bucket, collapsed row, fixture 5010, individual row still hidden) |

Audit probes rerun against the fixed sources (`xcrun swiftc -parse-as-library` with production `Notifications.swift` and `NotificationStore.swift`):

```text
probes/Race.swift
After successful acknowledgment: ["7:false"]
After older refresh completes: ["7:false", "6:false"] next: Optional(2)
Next page IDs: [7, 6, 5, 4] server ID8 read: true
Grouped actor: nil hidden by ignoring original member: false

2026-10-18 audit-probes/Probe.swift
Unread after acknowledgment: ["7:read=false"]
Unread after next page: [7, 6, 5] ; expected next unread ID 6, found: true
After successful refresh removes access to all targets: [] ; refreshError: nil
Recheck inaccessible unread row: server.read= false ; client.read= Optional(false) ; outcome= Optional(probe1.AcknowledgmentState.unknown)
```

Unit/contract target on the final code: 133 executed, 129 passed, 4 skipped (opt-in live), 0 failed (`.build/audit2-unit.xcresult` in the integration worktree). Two first-run failures were wrong test expectations, corrected to the specified behaviour: a re-fetched refresh returns the fresh first window `[7, 6]`, and ID 8 leaves memory rather than staying cached as read.

**Complete suite on the final code** (`.build/final-complete.xcresult` in the integration worktree; Xcode 27.1, iOS 27.0, “Fomio Release iPhone 17” `CAB241D5-6903-45BC-91E8-FDECC89F6D78`; code = `eef6b2f` plus the uncommitted audit fixes later committed on top): **183 tests — 174 passed, 7 skipped (4 opt-in live checks, 3 existing UI skips), 2 failed.** Unit/contract: 133 executed, 129 passed, 4 skipped, 0 failed. UI: 50 executed, 3 skipped, 2 failed. A first attempt (`final-complete.log`, earlier) was interrupted when the session ended and produced no result.

| Failure | Evidence | Rerun (same simulator and build, `.build/rerun2.xcresult`) |
| --- | --- | --- |
| `FeedAppearanceUITests.testDarkAccessibilityTextAndRightToLeftCaptures` (line 159, `Compact` menu item not found within 5 s) | After tapping Feed options, XCTest's “wait for app to idle” took 32 s (t 20.95 → 53.33) before the 5-s search; heavy host load from concurrent sessions | Passed 3/3 |
| `FomioUITests.testSwipeDismissalProtectsChangedWriting` (line 318, keyboard still present 5 s after Hide keyboard) | The toggle was tapped about 2 s after typing; the floating bar rides the keyboard and can still be moving (earlier probe: 300 pt within 0.4 s). The shared `dismissComposerKeyboard` helper does not yet use `tapSettled` | Passed 3/3 |

Neither test exercises the notification store or model changed by the audit fixes. They are recorded as intermittent under load, not as passes; no assertion was changed. Recommended test-only follow-up: use `tapSettled` in `dismissComposerKeyboard`.
