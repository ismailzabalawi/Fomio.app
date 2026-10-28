# Adaptive reading acceptance audit — 2026-10-21

Scope: the reviewed native adaptive browsing/search design and its IA/API contract. This is distinct from an App Store release, new backend deployment, live posting authorization or certification of every Discourse role. Existing passing tests are reused; they are not rerun merely to refresh dates. The chronological [evidence ledger](README.md) preserves failures and superseding results.

## Requirement ledger

| Requirement | Inspected evidence | Current conclusion |
| --- | --- | --- |
| Typed root/child/All scope shared by header, sidebar and directory | Adapter/domain cases in the172-test baseline; native sidebar parity a3c84cd0, chooser hierarchy/filter cases | Implemented and verified for the recorded catalog/fixtures; no new deployed-role claim |
| Local chooser filtering, ancestors, Cancel and honest partial catalogs | f6366c4c,5206b254,39d3e977; actual iPad chooser Zoom a3c84cd0 | Verified; local filter remains separate from discussion requests |
| Query grammar, numeric constraints, settings, encoding, exact joins, grouped-error-first decoding, no HTTP cache admission | [Baseline integration](final-unit-phone-integration-summary.json), [target counts](final-unit-phone-target-counts.json), AdaptiveSearchTests adapter cases |172 unit/contract passes plus3 phone UI passes;4 opt-in live skips. Post-fix integration68869872 adds current174 unit/contract passes and2 UI passes, with4 live skips |
| Initial/refresh/page-N recovery, stale completion rejection, manual Retry, rate-limit deadlines and per-viewer invalidation | Adapter/state baseline; native initial/refresh/page-N error journeys in ledger | Cross-window denial reproduced in b7d08b84; fixed by pausing each visible search at its new viewer identity.3ec0f82a passes22 focused checks;68869872 passes174 unit/contract and2 UI checks |
| Exact Search/Saved/notification/public-link destinations and retained reading position | bb34cc9f five native exact-route/anchor cases;3pt/6pt scroll assertions unchanged | Verified at app-handler level. Production Universal Link entitlements/delivery remain deferred |
| Draft identity/text/parent/photo recovery through size changes, Keep/reopen and auth intent | Phone orientation cases;1649be54 and8c48709c actual Duo roundtrips; peer editor Zoom/focus result | Recorded fixture/native journeys pass. No live write inferred |
| Compact space use, dark wordmark and one/two/three-pane native adaptation |0ff7ced1;365eda30;bad7850d and inspected captures | Targeted five-layout visual/interaction checks pass, including actual native fold/window-control clearance |
| Large text/RTL semantic rendering and native size changes | Phone actual AX5/in-place focus; [iPad native growth](ipad-native-text-growth-summary.json), AX5 capture | Reported heading22.5→69pt and body20→128.5pt grow and restore; exact scope retained |
| VoiceOver chooser/search/error/Retry/Cancel in each layout | Phone f63df1c6/453e46eb; [Closed Duo](duo-closed-voiceover-final-summary.json); [Open native actions](duo-open-voiceover-manual-observations.json) | Phone and Closed Duo gesture cases pass. Open native accessibility actions verified separately; automated Open touch run remains failed. Wide native chooser/filter proof is supplemented by completed native Cancel/search/error/Retry/Cancel actions with off restoration. Narrow iPad b3368447 passes one externally driven native-action observation including cleanup. Earlier interrupted/touch runs remain failed; these action reviews do not establish full rotor/touch traversal |
| Current failure announced once without stealing focus, clear accessible Retry/Cancel; Reduce Motion | Repeated-attempt identity/state tests; guarded native announcement source; inspected phone query/Retry focus;ce613e56 real Reduce Motion recovery | Native state/focus and functional Reduce Motion verified. Human confirms the failure was announced once during VoiceOver runs (2026-10-21); tools do not independently hear audio |

## Audit findings kept separate from functional results

The unfiltered UITextField clipping audit and iPad Dynamic Type audits remain **failed**, not excluded or relabeled as passes. Minimal native references reproduce the warnings. Actual system-size measurements and inspected complete text provide contrary functional evidence for the reported controls. See [native field reference](native-field-reference/README.md), [native Dynamic Type reference](native-dynamic-type-reference/README.md), and [current iPad audit](ipad-unfiltered-current-summary.json). This is a documented diagnostic limitation; it is not a complete accessibility certification.

## Final audit and remaining release limits

The remaining targeted native-action checks are complete. [Wide iPad observations](ipad-wide-voiceover-manual-observations.json) verify chooser Cancel and search/error/Retry/Cancel with real VoiceOver on. [Narrow iPad b3368447](ipad-narrow-voiceover-final-summary.json) passes one observation case at actual375×508, Arabic AX3/dark, including original-scope/query retention, recovery, VoiceOver-off cleanup and native window restoration. The human confirms the spoken failure is announced once. Root phone, Duo and Air13 VoiceOver are independently restored off. No already-passed baseline suite was repeated in this final pass.

- Cross-window permission recovery is resolved by the recorded22 focused checks and174 unit/contract +2 UI integration passes; no rerun was needed.
- Full rotor/swipe traversal and physical-device certification remain unestablished. Open Duo and iPad action reviews prove native accessibility semantics at their stated layer. In the375×508 AX3 capture, lower chooser/error content extends below the initial viewport; native action availability does not prove simultaneous visible fit or complete gesture traversal.
- The unfiltered audit warnings and failed touch/interrupted runs remain recorded above. No warning was suppressed or failed result relabeled.
- Ordinary non-staff private-category/PM deployed coverage remains unavailable with the admin-only account; local14-role examples are separate. Production OS Universal Link delivery/entitlements remain deferred.

Verdict: **the requested remaining targeted accessibility checks and final acceptance audit are complete, with documented limits**. The native adaptive design has implementation, API/state, five-layout and targeted accessibility evidence. This is qualified functional acceptance, not unconditional accessibility/release certification or a100-percent claim about unsupported checks. No app/backend behavior changed during this final pass. Current inspected source hashes remain in [the handoff snapshot](acceptance-source-hashes.json); historical failed runs remain failed.

## Design conformance follow-up — 2026-10-21

A later review compared the build with the [Adaptive Reading mockup](https://claude.ai/design/p/16bf8d13-06dd-4c18-a74b-59ebee5a0b6b?file=Fomio+Adaptive+Reading.dc.html) rather than with functional checks alone. It found three gaps, now fixed. The verdict above covered functional and accessibility behavior; it did not establish conformance to the mockup's layout rules.

| Mockup rule | Before | Now |
| --- | --- | --- |
| Two panes need 300 + 420 pt and the sidebar 1080 pt, scaled ×1.15 at Large (23 pt body) and ×1.6 at AX 200% (34 pt). Sidebar 260 pt; list up to 380 pt. | Minima scaled with the full body ratio (`@ScaledMetric`, about ×2.35 at AX3). The 1366 pt iPad Air fell back to one pane at AX3 (`ipad-air-1366-arabic-ax3-chooser.png`). Sidebar 220 pt scaled. | `ReadingLayout.scale(for:)` follows the mockup's two points and continues the same rate beyond 34 pt. AX3 needs 1329 pt, so the iPad Air keeps two panes. Sidebar 260 pt; list width min 300k, ideal 36 % of the remaining width, max 380k. |
| The chooser is a popover only at two-pane Standard text, and a sheet at compact width or Large/AX. | Always a popover in regular width. At AX3 its lower rows were clipped. | The style is chosen when the chooser opens: popover below `.xxxLarge` in a regular (two-pane) column, otherwise a form sheet. Only one presentation exists at a time, so the earlier resize dismissal problem cannot recur. |
| A kept reply shows as "Draft reply … Resume" in the discussion, and Reply continues it. | Reply always created a new draft, so the same post could collect several. The kept text was only reachable from Me › Drafts. | `KeptReplyCard` appears under the opening post when an unsent reply on that topic is not open. Reply on a post with an exact kept draft reopens it instead of starting another. |

Evidence (sources in [design-conformance/source-hashes.json](design-conformance/source-hashes.json)):

- Unit/contract: 180 tests, 176 passed, 4 opt-in live tests skipped, 0 failures (iPhone 17, iOS 27.1). New cases: `testReadingLayoutFollowsReviewedMinimaAndSlowerTextScaling` and `testKeptReplyIsOfferedOnItsTopicAndReplyContinuesIt`.
- iPad Air 13-inch UI: 5 of 5 passed. These were the wide sidebar scopes, independent windows, rotation with reply and Keep draft, chooser filter across rotation, and AX3 RTL dark. The AX3 case now also asserts `reading-two-pane` at 1366 pt and a chooser field wider than 400 pt (form sheet, not the 360 pt popover).
- Inspected captures: AX3 RTL chooser sheet over two panes, kept reply card after Keep draft.

Not rerun in this pass: the iPhone `AdaptiveReadingUITests`, Duo Open/Closed, narrow iPad and VoiceOver journeys. Those earlier results predate these sources. The hashes in `acceptance-source-hashes.json` no longer match `AppState.swift`, `FomioApp.swift`, `AdaptiveReadingLayout.swift`, `CommunityScopePicker.swift`, `DiscussionView.swift` or the strings files.

### Second pass — remaining mockup differences

The second pass fixed the differences the first pass left open. Only the deliberate per-tab scope remains.

| Mockup rule | Now |
| --- | --- |
| An empty community says "No discussions in X yet" and offers **Choose a community**. | A centered state with that copy; its button opens the same chooser through the picker's request trigger. All communities keeps the create hint. |
| No matches: "No topics in X match "…"", with a hint and **Clear search**. | Scoped and unscoped wording with the hint. Clear empties the query and refocuses the field. Arabic isolates the query (FSI/PDI). |
| Sidebar hide/show, root marks, counts, accent-filled selection, 260 pt width. | The sidebar header has a hide button. While it is hidden, destinations return to the tab bar and a show-sidebar control sits at the top-leading corner of the list header. Roots show `CategoryMark`, All shows a neutral mark, and children are indented. Counts come from Discourse `topic_count`, add visible children, and are hidden if any count is missing (see the API reference). |
| Two-color wordmark: dark letters with the accent curve, and the dark-app variant. | New `wordmark-color` image set built from the mockup's two PNGs (light and dark appearances, original rendering, never mirrored). |
| On Home without a sidebar, the wordmark sits in a row above the title; the title is 24 pt bold with an accent chevron. | Wordmark row as described. The title is 24 pt bold, scaled with `.title2`. The toolbar wordmark is removed. |
| The chooser filters by community name. | Names only. |
| The magnifier toggles: it reveals and focuses, and it hides an open, empty search. | As described. Its label changes to "Hide search" and it is tinted while search is open. |

Two tests change because of this behavior. `search()` reveals only when the field is closed. The chooser test scrolls the iPad popover until a lower row exists, because the lazy list does not create it before that. Two helpers were made robust: the AX3 sheet test waits for dismissal, and the feed drag helper stops within 12 pt instead of making a drag short enough to register as a tap.

Results on these final sources ([hashes](design-conformance/source-hashes.json)):

- iPhone 17: unit/contract 181 tests, 177 passed, 4 live tests skipped. The full UI target (run before the last header adjustment) had 96 tests, 58 passed, 28 skipped and 10 failed. Rerun on final sources, `AdaptiveReadingUITests` plus `FeedAppearanceUITests` had 36 tests, 23 passed, 11 skipped and 2 failed. That rerun included the Arabic Cards feed drag, which now passes.
- iPad Air 13-inch: `IPadReadinessUITests` plus `AdaptiveReadingUITests` had 39 tests, 20 passed, 16 skipped and 3 failed. `testListDetailAndReplySurviveWindowRotation` failed in `launch()` because a floating window did not expand; it passed alone on the same sources and in both earlier runs.
- New checks pass: the empty state opens the chooser; Clear and the magnifier toggle; sidebar hide → two panes plus tab bar → show → three panes; scope counts (unit test).

These failures remain. None comes from this pass, and none was suppressed:

| Test | Reason |
| --- | --- |
| `testInlineSearchFailureAccessibilityAudit` (iPhone, iPad) | The documented UITextField "Text clipped" finding, already failed in three earlier runs. |
| `testSelectedDiscussionReturnsToRetainedSearch` (iPad) | Fixed later the same day: the test now skips unless the window is in the one-pane layout. It skips on the iPad and passes on the Isolated Suite iPhone. |
| `testCardCasesOmitAbsentFieldsAndKeepSeparateTargets` (iPhone) | A failed-media row still reports "Has image"; card media labeling is unrelated to the browse header. |
| `testHeadingMenu…`, `testVisualDraftRecovers…`, `testVisualHeadingMarkdown…`, `testVisualChecklist…`, `testLargestTextSelectionFitsBar` (iPhone) | **Correction:** the earlier claim that `composer-more` was gone was wrong. It is set in UIKit by `ComposerMoreMenu` in `NativeComposerEditor.swift`, and a truncated search missed it. See the follow-up below. |
| `testSearchKeepsQueryAndResultsAfterDiscussion` (iPhone) | Fixed later the same day: it now uses the collapsed adaptive search. It passes on the Isolated Suite iPhone and on the iPad (two panes). |
| `testReportCustomReasonAndBlockThenUnblock` (iPhone) | Block feedback ("This reply is hidden.") did not appear. Safety flow; not touched here. |

There is no earlier full-target iPhone baseline for these uncommitted sources, so the report/block and media-label failures are attributed from what the tests exercise, not from a before/after run.

Inspected captures: empty community, dark AX3 header, Arabic RTL header, sidebar marks and counts, sidebar hidden with show control.

Still deliberately different: scope is kept per tab (IA map decision); the mockup shares one scope. Not rerun: Duo Open/Closed, narrow iPad and VoiceOver journeys.

### Follow-up — stale and environment-sensitive UI tests

Two tests changed:

- `testSearchKeepsQueryAndResultsAfterDiscussion` now uses the collapsed adaptive search. It waits for `scoped-search-results`, because the plain feed already lists `topic-4182`. On return it takes Back only in one pane.
- `testSelectedDiscussionReturnsToRetainedSearch` skips unless the layout is `reading-one-pane`.

The composer tests were not stale: every identifier they use still exists. They were rerun on the Fomio Isolated Suite iPhone 17 (`BA47EA08`), the simulator that produced the earlier clean 183-test run:

| Test | Result | Observation |
| --- | --- | --- |
| `testHeadingMenuEnablesVisualInlineFormatting` | Pass | Failed earlier only on the general iPhone 17 simulator. |
| `testVisualDraftRecoversAfterTerminationWithExactMarkdown` | Pass | Same. |
| `testVisualHeadingMarkdownPreviewAndReturnPreserveDraft` | Pass | Same. |
| `testVisualChecklistCanBeCreatedAndCheckedWithoutSource` | Fail | After tapping Turn into › Checklist the menu stays open and no `composer-task-0` appears. |
| `testLargestTextSelectionFitsBar` | Fail | At AX XXXL the body field is at y 788–988 on an 874 pt screen, so the tap cannot focus it. |
| `testNativeFormattingCaretTypingSurvivesSourceSwitch` | Fail (intermittent) | `composer-more` exists but "Edit in Markdown" was not found; the test passed in the previous full run. |
| `testSearchKeepsQueryAndResultsAfterDiscussion` | Pass | Also passes on the iPad. |
| `testSelectedDiscussionReturnsToRetainedSearch` | Pass | Skips on the iPad as intended. |
| `testReportCustomReasonAndBlockThenUnblock`, `testCardCasesOmitAbsentFieldsAndKeepSeparateTargets` | Fail | Unchanged from before. |

The three composer failures are in the uncommitted editor-prototype code, which these passes did not modify. These tests were left unchanged rather than loosened.

### Follow-up — composer failure diagnosis

The three remaining composer failures were investigated against a scratch copy of committed `HEAD` (`27db168`) and a copy of the current sources. Both copies were built separately, and the checkout and git state were not touched. All runs used the Fomio Isolated Suite iPhone 17 simulator.

- **Checklist conversion** and the **intermittent "Edit in Markdown"** have one cause, and it is not in the editor. Temporary logging on `ComposerTextView` (copy only) recorded keyboard show → hide → show. The view never resigned or regained first responder in between, and `reloadInputViews` was never called. The hide follows XCTest's `typeText`; the software keyboard returns on the next touch. In the meantime the floating bar sits at the safe area, then jumps above the keys, so a tap aimed at the old position misses. Committed `HEAD` failed the checklist test 1 of 2 times in the same way. The same race affected three other tests: heading menu, draft recovery and heading Markdown preview.
- **AX XXXL body**: committed `HEAD` fails 2 of 2 identically. At this size the community row and prefilled title fill the 874 pt screen; the empty body starts at y 788, under the floating bar. That is ordinary scroll content. The test tapped it without scrolling, and its earlier swipe hit the feed behind the sheet.

No editor change was needed. Test changes in `FomioUITests.swift`:

- `tapSettled(_:_:anchor:)` waits until a bar control, or a visible anchor in the same scrolling strip, has kept one frame for a second. It is used for the Turn-into and More taps that directly follow `typeText`: checklist, Markdown switch, heading menu, draft recovery and heading Markdown preview.
- The large-text test scrolls the composer's own scroll view until the body's first line clears the bar, then taps that line.

Results (Isolated Suite iPhone 17):

| Run | Result |
| --- | --- |
| Checklist, Markdown switch, large text ×3 iterations | 9/9 passed |
| Heading menu, draft recovery, heading Markdown preview ×3 | 9/9 passed |
| Full `FomioUITests` class | 40 tests, 34 passed, 5 skipped, 1 failed (`testReportCustomReasonAndBlockThenUnblock`, unchanged and out of scope) |

The keyboard flicker is a simulator/XCTest input effect; nothing here shows it on a device. The report/block failure and the card media-label failure remain open.

### Follow-up — block feedback did not appear

`testReportCustomReasonAndBlockThenUnblock` failed at "This reply is hidden." because the open discussion went blank after the block: no posts, no progress indicator, no error. Cause, in the uncommitted safety work:

1. `AppState.changeBlocking` clears every tab's `discussions` cache, so unblocking reloads content the server omitted.
2. The open route keeps its mounted `DiscussionView`, and `discussionState(_:in:)` hands it a new, empty `DiscussionState`.
3. `DiscussionView` loaded only from `.task { if state.page == nil … }`, which runs once per view lifetime. The replacement state was never loaded.

Fix: in `DiscussionView.swift` that task is now `.task(id: ObjectIdentifier(state))`, matching how `FeedView` already keys its load to the feed state. A cleared cache now reloads in place. The blocked author's post renders as "This reply is hidden." and the title as "Discussion by a blocked member". Trade-off: clearing the cache still drops that discussion's previous scroll anchor and expanded branches.

The same wide run surfaced one more instance of the keyboard race, in `testArabicComposerPreservesMixedTextAcrossModesAndRotation`. Every bar tap within two lines of `typeText` now uses `tapSettled`: 13 call lines.

Results (Isolated Suite iPhone 17):

| Run | Result |
| --- | --- |
| `testReportCustomReasonAndBlockThenUnblock` ×3 | 3/3 passed |
| Unit/contract + `FomioUITests` + `AdaptiveReadingUITests` (before the last tap fix) | unit 181: 177 passed, 4 skipped; UI 70: 52 passed, 16 skipped, 2 failed (known "Text clipped" audit; the Arabic composer race fixed afterward) |
| Full `FomioUITests` class, final sources | 40 tests, 35 passed, 5 skipped, **0 failed** |

Still open: the `testInlineSearchFailureAccessibilityAudit` "Text clipped" finding and the feed card media label (`testCardCasesOmitAbsentFieldsAndKeepSeparateTargets`).

### Follow-up — failed topic media never fell back to text

`testCardCasesOmitAbsentFieldsAndKeepSeparateTargets` failed because card 5004 (the fixture's "thumbnail failed to load" case) kept its "Loading image" placeholder and the "Has image" label indefinitely. Diagnosed in a scratch copy with temporary logging and a label-sampling probe:

- URLSession fails the fixture URL at once (`file:///…` 0.00 s; `https://fomio-fixture.invalid/…` 0.05 s, host not found).
- In the card, `AsyncImage` ran its load task, reported `empty` once, and never moved to `failure`. It was not being recreated.
- A reachable image (`https://www.apple.com/favicon.ico`) in the same slot moved from `empty` to `success`, so placement and tasks were fine.

The cause is `AsyncImage` not reporting failure for unreachable hosts or missing files. Live, an unreachable image host or an offline device would leave a permanent placeholder announced as "Has image", instead of the intended text fallback.

Fixes:

- `TopicMedia` (`TopicCard.swift`) loads remote media with a `URLSession` request: 15 s timeout, non-2xx status, or undecodable data counts as failure. It decodes off the main actor and ignores cancellation from recycled rows. Failure sets the existing `failed` binding, so the slot is removed.
- The fixture's broken image is now `https://fomio-fixture.invalid/missing-thumbnail.jpg`. It passes `PublicMedia`'s https rule like live data and fails promptly (RFC 6761 reserved domain).
- The test now waits up to 10 s for the label to drop "Has image", because failure is asynchronous.

Results (Isolated Suite iPhone 17): a reachable image still loads (scratch probe). Over two iterations, `FeedAppearanceUITests` passed 6/6 each time and the unit/contract tests had 0 failures (4 opt-in live skips per iteration).

Remaining open from this audit: the `testInlineSearchFailureAccessibilityAudit` "Text clipped" finding.

### Follow-up — "Text clipped" audit resolved (2026-10-22)

The `testInlineSearchFailureAccessibilityAudit` finding flags the topic search field's `SwiftUI.UIKitTextField` ("may be clipped at larger Dynamic Type sizes"). It is a prediction, but it is real at the level the audit checks: SwiftUI's single-line `TextField` is backed by a `UITextField` that does not opt into Dynamic Type itself, because SwiftUI scales the font from outside.

A disposable three-variant reference app, run with the `.textClipped` audit only on the Isolated Suite iPhone 17, settled it ([sources](native-field-reference/VariantsApp.swift.txt), [test](native-field-reference/VariantsUITests.swift.txt), [report](native-field-reference/variants-report.txt)):

| Variant | Audit |
| --- | --- |
| SwiftUI `TextField` (single line, as Fomio used) | Text clipped |
| SwiftUI `TextField(axis: .vertical)` | no issues |
| UIKit `UITextField` with `adjustsFontForContentSizeCategory` | no issues |

The vertical field is still exposed to XCTest as a text field (type 49) and reports its value. Its binding intercepts Return to end editing without storing a newline.

Fix (`FeedView.swift`): the topic search field is now `TextField(…, axis: .vertical).lineLimit(1...3)`. Return still means Search, and a long query wraps at large text instead of scrolling sideways. No issue handler or exclusion was added.

Results:

| Run | Result |
| --- | --- |
| `testInlineSearchFailureAccessibilityAudit`, iPhone (standard dark; Arabic AX3 dark RTL) | **passed** |
| Same, iPad Air 13-inch | **passed** |
| Unit/contract (iPhone) | 181 tests, 177 passed, 4 skipped |
| `AdaptiveReadingUITests` + search test (iPhone) | 31 tests, 19 passed, 11 skipped, 1 failed: `testPublicLinkRendersExactReplyOutsidePreviousCommunity` ("failed to determine hittability"), which then passed 3/3 alone |
| `IPadReadinessUITests` + `AdaptiveReadingUITests` (iPad) | 21 passed, 17 skipped, 1 failed: the intermittent `launch()` window expansion; that test and the audit then passed alone |

This supersedes the earlier "unfiltered UITextField clipping audit remains failed" statement for the topic search field. Not resolved here:

- The opt-in iPad system-size audit (`testNativeAccessibilityAuditWithSystemTextSizing`) ended with "Audit failed to complete in time" (code −56). It is inconclusive, not a pass.
- The community chooser's "Find communities" field still uses the single-line pattern and would likely draw the same prediction if audited.
