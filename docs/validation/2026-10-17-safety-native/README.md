# Reporting & Safety native validation — 2026-10-17

## Report recovery fixes — 2026-10-18

Follow-up to the final diff review of `6837b25` (changes in the reporting worktree):

- A 401 while loading/rechecking report context now requests the existing sign-in recovery, with Send disabled until authorization and context reload finish. The sheet observes an already-set sign-in notice on presentation too. A new load clears the old notice before suspending, so reopening after sign-in does not trigger another sign-in from a stale notice. Retained reason/details are restored only for the same account; no automatic submission.
- A denied submission keeps Send and selection locked throughout the fresh report-status read. The lock clears after the read finishes, showing Already reported or Unavailable as before.
- Three new state regression tests failed on the prior code, then passed with the fixes. They cover initial context expiry, expiry during an input-preserving retry, and a held post-denial status read (both received and not-received outcomes), including a second explicit send attempt while locked.
- Added a native UI regression using fictional `--report-context-expired` (one context failure, then normal fixture behavior): opening Report → sign-in → unselected report form → explicit selection and Send → received.

Fresh validation: Xcode 27.1, iPhone 17 Pro Max / iOS 26.1. **29 passed, 0 failed, 0 skipped**: SafetyContractTests (11), SafetyStateTests (13), SafetyPreviewTests (4), and the new expired-context SafetyUITests case (1). The result bundle is `test_sim_2026-10-17T22-14-22-309Z_pid88222_93000c61.xcresult` in the local XcodeBuildMCP workspace. No live requests, backend/settings edits or translation edits. Existing release items below remain open.

## Final run of record — 2026-10-18

This run is on the final committed tree, including the review fixes: Ignore entry checks the member card before opening the sheet, and failures that aren't denials show as "Couldn't ignore" rather than "can't ignore". Simulators were dedicated to this run (other sessions used other devices).

| Run | Device | Result |
| --- | --- | --- |
| `xcodebuild test` (all `FomioTests` + `FomioUITests`) | iPhone 17 Pro, iOS 26.1 | **169 tests: 164 passed, 0 failed, 5 skipped** (live opt-in tests). Unit 121 (incl. `SafetyContractTests` 11, `SafetyStateTests` 10, `SafetyPreviewTests` 4); UI 48 (incl. `SafetyUITests` 8, `SafetyPreviewUITests` 4). |
| `SafetyUITests` + `SafetyPreviewUITests` | iPad Pro 11-inch (M5), iOS 26.1 | **12/12 passed on the first attempt.** |

Earlier dated results below are history. The 2026-10-17 iPad runner-kill flake did not recur in this run.


Branch `codex/discourse-reporting-ia` (working tree, uncommitted). Xcode 27.0, iOS 26.1 simulators. Everything ran in **fixture mode**: simulated outcomes, fictional content, no requests to a community. This is native/state evidence, not live verification.

## Results

| Run | Device | Result |
| --- | --- | --- |
| Full suite: `FomioTests` + `FomioUITests` | iPhone 17 Pro sim | **Unit 116 executed, 0 failures, 4 skipped** (pre-existing live opt-in). **UI 44 executed, 0 failures, 1 skipped** (live opt-in). |
| New `SafetyContractTests` | (in the above) | 11/11. Payload shapes for `post_actions` (post vs topic ID, `flag_topic`, no staff keys) and `notification_level` (Forever, no `acting_user_id`, `normal`); error mapping (403/404/429/401 thrown; 5xx/malformed 2xx → unconfirmed; Ignore 422 → `invalid`); catalog filtering/order; acted → already; card/current-user decoding; server-only resources; attributed quotes; topic `can_flag_topic`. |
| New `SafetyStateTests` | (in the above) | 9/9. Required details enforced without a request; single request in flight with locked inputs; unknown receipt → Check status before Send; recoverable errors keep input; offline sends nothing; 401 keeps input across sign-in with no automatic submit; denied/already/removed/new-member (Illegal only)/topic catalog; guest gate rechecks without sending; Ignore success only after confirmation and uncertain needs Refresh; staff/new-member denials; account isolation; Show once keeps the preference; list failure is scoped and retryable. |
| New `SafetyUITests` | iPhone 17 Pro sim | 8/8 (in the full run). |
| `SafetyUITests` | iPad Pro 11-inch (M5) sim | 8/8 across reruns. **First run: 4/8 passed, 4 ended with "Test crashed with signal kill"** (runner killed; no Fomio crash report). Rerun of those four: 3 passed, the accessibility/RTL test was killed again (`signal term`), then passed alone. Recorded as runner instability while another session ran UI tests on the same machine; not a clean first-pass result. |

## Captures (this folder)

`iphone-R03-reason-sheet`, `iphone-R06-received`, `iphone-R10d-unknown-receipt`, `iphone-A02-accessibility-text` (title moves into the body, Send shortens), `iphone-A03-rtl-dark-rate-limited` (mirrored; icon, bold title and outline, not color alone), `iphone-I04-hidden-op-and-reply` (client-hidden OP plus server-hidden reply, visible ••• on every post), `iphone-I05-ignored-users`, `iphone-H02b-safety-guest` (fixture supplies no resources, so pending states show), `ipad-A01-report-form-sheet`, `ipad-I07a-new-member`.

## Manual simulator checks

Report reply → Spam → Send → Report received → Ignore devon… → Forever → confirmed profile state with activity collapsed; hidden OP and reply placeholders; Show once on a server-blanked reply (fresh fetch) → Hide again.

## Not verified

- **No live run.** Live adapters are covered by stubbed contract tests only. The deployed-member round trips were waived by the user (see stage gates). Plugin effects, real review-queue delivery and issued-key scopes remain release items.
- VoiceOver was not driven by hand. Labels, traits and identifiers are asserted only indirectly through UI tests. No physical device.
- Arabic: layout mirroring verified. As of 2026-10-18 the new safety strings are in `ar.lproj` as **machine-quality drafts that still need native-speaker review** (see the follow-up below).
- Ignored-author suppression covers discussions (OP, replies, attributed quotes), profile activity and draft quotes. Since 2026-10-18 it also covers feed cards, search snippets and reply/mention notifications (see the follow-up below). Saved items and onebox/link previews are still not projected: their payloads don't carry the author.
- Contact support opens Mail only when the server publishes a valid `contact_email`. Whether the live value is the staffed support destination is unconfirmed by operations.
- Not uploaded to TestFlight; no App Review claim.

## Follow-up — 2026-10-18: ignored previews outside discussions, Arabic safety copy

**Behavior** (fixture mode; nothing live):
- Feed cards keep title, author and metadata, but collapse the excerpt and media to “Preview hidden because you ignore {user}” with Show once. Card cases with an empty author are never collapsed.
- Search results collapse the snippet when the matched post's author is ignored. That author is `matchAuthor`, or the topic author for opening-post/title matches.
- Reply/mention notifications from an ignored actor collapse to “Notification from someone you ignore”. Show once restores the row.
- Reveals are per item (`IgnoredPreview`), last for this launch only, never change the preference, and reset on a preference change, an account change or sign-out.

**Arabic.** About 120 new Reporting & Safety keys were added to `Fomio/Resources/ar.lproj/Localizable.strings`. The keys were extracted from compiler `.stringsdata`, so they match the source exactly. The block is marked “NEEDS NATIVE-SPEAKER REVIEW”. “Discard” reuses the app's existing «حذف», never the Ignore verb. Report reasons stay server-provided. Some pre-existing non-safety strings remain untranslated; they were out of scope.

**Tests** (iPhone 17 Pro Max, iOS 26.1, a dedicated simulator):
- `SafetyPreviewTests`: 4/4. Known-author-only hiding, per-item reveals, resets, fixture author fields, and an Arabic format-argument parity check across **every** entry in `ar.lproj` (positional arguments allowed), plus coverage of key safety strings.
- `SafetyPreviewUITests`: 4/4. Feed card, search snippet and notification collapse with Show once; Arabic report sheet. The Arabic heading check first failed on an exact-label match. Interpolated arguments carry bidi isolate marks, so the test now matches the fixed text and the noun separately; the UI itself was correct.
- Full suite (the linked session's run, before the parent's final review fixes): unit 121 executed, 4 skipped, 0 failures; UI 48 executed, 1 skipped, 0 failures.
- Capture: `iphone-arabic-report-sheet.png` (Arabic chrome; reason names are the fixture's English sample catalog).
