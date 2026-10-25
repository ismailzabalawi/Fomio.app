# Validation and release readiness

Current submission status (2026-10-18): see [App Store preparation](app-store-submission.md). Build 0.8.0 (7) is signed, uploaded, processed and added to a Draft Submission with Ready for Review status after explicit owner approval. Final Submit for Review remains pending. Native safety/deletion, live policy/contact corrections, approved site permissions, privacy labels and native listing copy are implemented. Member authentication and safety read contracts pass. Required native iPhone/iPad screenshots are uploaded; the disk blocker is resolved. Physical/TestFlight acceptance remains. Historical fixture/upload evidence below is not current submission acceptance.

Final preparation evidence: **96 unit/contract tests passed**, four live tests skipped; **one focused deletion UI test passed**. Signed Release archive and a local App Store distribution IPA exported successfully. Signature and packaging verification passed; no upload/submission performed. [Exact results, artifact paths and limits](validation/2026-10-18-submission/README.md).

Baseline: 2026-10-03. The fixture milestone is delivered. Live release is **not accepted**. [Implementation status](implementation-status.md) contains exact simulator result-bundle names and inspected captures; [API reference](discourse-api-reference.md) contains source evidence.

## Recorded evidence

24 unit tests and 8 native UI tests passed across the full regression run and targeted reruns, on iPhone 17 / iOS 26.1. This is aggregated evidence, not a claim of one final all-green 32-test run. The photo test’s dismissal timing was corrected and rerun; the added search test exposed a hidden native field, corrected with explicit drawer placement and rerun. iPhone and iPad Pro 11-inch (M5) native launches/builds succeeded. Final tools reported no build warnings.

| Area | Automated evidence | Remaining acceptance |
| --- | --- | --- |
| Core navigation/auth | Reply/draft journey; guest sign-in restores composer without posting; missing live configuration | Real browser callback, guest/member/denied and login-required site |
| Nested discussion | Root/child pagination, exact ancestry/context, required capability; notification #14 | Live sorting/depth cap, missing ancestors, revoked visibility and real shared targets |
| Drafts/accounts | Durable new-store recovery, account isolation, sign-out cleanup, save failure, interrupted submitting | Device termination/background lifecycle and protection behavior; corrupted/versioned records |
| Photos | Missing-photo recovery unit tests; failed upload → warning → resumed writing UI | Real picker/upload/cancel, deployed limits, secure media and durable uploaded references |
| Posting | Published/pending/uncertain locks, no concurrent/automatic retry, queue decoding, malformed success uncertainty, duplicate-warning UI | Deployed rejection/moderation, expiry, reconciliation proof, required tags/fields |
| Search | First page, post order/exact target decoding, query/results survive discussion Back | Live pagination/search semantics and reading-anchor interaction |
| Transport | Relative roots, logical links, 401 and 429 meanings, optional/deleted DTOs | Anonymous/member/403/revoked/server failures, same-origin redirect behavior and rate limits |
| Security | Actual simulator Keychain round-trip/removal; account draft isolation | Device-only Keychain lifecycle and callback validation against deployment |
| Accessibility/layout | Dark accessibility3 composer reachability; visually inspected phone/iPad Home | Full VoiceOver, all text sizes, contrast/transparency/motion, RTL, keyboard, narrow phone and iPad resizing |

UI tests cover eight journeys: core draft keep, guest auth, exact notification, uncertain retry, failed-photo recovery, dark accessibility text, search return, and unconfigured live mode. Unit tests are in `FomioTests/FomioTests.swift` and `ContractTests.swift`; transport responses are sanitized local stubs, not captured production fixtures.

The 117-render browser pass validates design references only. Native screenshots are visual evidence of those captured screens. Neither establishes live capability or complete accessibility compliance. MCP runtime hierarchy capture was unusable in the latest manual capture pass; XCTest supplied interaction evidence.

## Deployment inputs required

- Supplied HTTPS base URL, relative root and deployed revision alignment.
- Enabled features/plugins/settings, specifically `nested_replies_enabled` and depth/sort behavior.
- Anonymous/member/denied accounts and a way to exercise expiry/revocation and rate limiting.
- Approved user-key scopes, callback URL/allowlist and app callback registration.
- Site posting constraints, required fields/tags, upload limits/storage/secure-media contract.
- Pending-author visibility and evidence sufficient to reconcile an uncertain write.
- Signing (bundle identifier `com.fomio.mobile` and the `AppIcon.icon` app icon are configured), and supplied link domains/entitlements if production universal links are enabled.

Do not mark an endpoint live verified from source or a successful fixture test. Do not change the backend to satisfy the client without separate authorization.

## Native acceptance procedure

1. Run the scheme’s unit and UI targets on a clean supported simulator; record build, runtime, device, OS, result bundle and commit/revision if available.
2. Complete Home → directory → child community → discussion → reply/quote/create. Verify inherited destination, Back, per-tab path, query, expansion and loaded branch retention.
3. Terminate/background during editing, upload and submitting. Resume in the same account and another account. Exercise save failure, explicit discard and sign-out deletion.
4. Verify both missing-photo recovery actions; successful/failing/cancelled uploads and disabled Post while unresolved.
5. Exercise published, queued, rejected, expired and uncertain outcomes. Double tap Post; confirm no concurrent submission. Verify Check again remains locked when inconclusive and manual retry requires warning.
6. Navigate notification/shared-link targets, deep threads, missing/deleted/denied ancestry and independent pagination errors.
7. On device and simulator, audit VoiceOver labels/focus, Dynamic Type through accessibility sizes, contrast/transparency/motion settings, RTL, external keyboard, narrow phone, rotation and iPad resizing/sidebar/form sheet.
8. Repeat relevant journeys against supplied live deployment with per-user credentials and sanitized recordings. Verify unsupported content has a valid original destination.

Record pass/fail/blocked with evidence and observed behavior. A test marked blocked is not a pass. Keep credentials/private content out of documentation and captures.

## Known follow-up work

The lightweight native cooked renderer, secure media, site-specific posting fields, live capability detection, pending/uncertain reconciliation, full accessibility/device proof and production signing/icon/link resources remain open. Navigation/reading caches are in memory, and supporting list views may reload; there is no durable whole-session restoration. Draft schema migrations/corruption isolation are not implemented. These limits should be assessed explicitly before release.

Out of the original MVP: offline sending queue, server drafts, push transport, Hot/tracked feeds, notification-level controls, private messages/chat, AI, advanced settings, editing and formatting modes.

2026-10-18: the user identified properly wired notifications as a pre-public requirement. The [notifications IA and integration map](notifications-ia.md) scopes inbox/read/count corrections, grouped destinations, foreground freshness and push/relay/device acceptance. Push remains unimplemented; this planning requirement does not establish relay configuration or device delivery.

**Notifications implementation (2026-10-18, branch `claude/fomio-notifications`, not merged or uploaded):** inbox, destinations, exact acknowledgment, totals, reconciliation, account isolation, device-setup states and incoming-tap boundary are implemented and fixture/stub tested ([validation](validation/2026-10-18-notifications/README.md)). Live acceptance is not done. External push dependencies, none provisioned or assumed:

1. A Fomio-owned HTTPS relay that receives Discourse's hub envelope (validates `push_api_secret_key`), maps `client_id` to APNs tokens and sends via an APNs key for team `LK9253R3XB`, topic `com.fomio.mobile`, sandbox and production.
2. An authenticated device-enrollment contract (client ID ↔ token ↔ account binding, rotation, deletion on sign-out/revocation) that does not hand the relay a user API key; retention, retry, deduplication and monitoring policy.
3. Discourse admin settings: the relay URL in hidden `allowed_user_api_push_urls`, `push_api_secret_key`; `push` already appears in the recorded `allow_user_api_key_scopes`.
4. App: Push Notifications capability/`aps-environment` entitlement and profile, a re-authorization that sends `push_url` (existing keys have none), APNs registration wired to the enrollment API, privacy-label review.
5. A tap payload carrying `notification_id`: the hub envelope has none, so acknowledgment from a push needs a verified server-side addition (e.g., a plugin payload modifier) or remains disabled.

Until these exist, live Settings truthfully show alerts as not available.

## Keyboard follow-up — 2026-10-04

Implemented a native single-line title field with distinct title/body focus, native Next/Done keyboard controls, interactive dismissal in composer/search/directory, retained search query on submission/navigation, Command-Return for guarded Post and Escape for protected Cancel. Native text selection is captured/restored through Keep editing and the community chooser; the Photos picker uses the same suspension path. Composer recovery messages receive scroll/accessibility focus, with Reduce Motion respected. Editing focus is cleared before sending and when inputs lock. No keyboard-height constants or custom focus navigation for ordinary buttons were introduced.

New regression coverage checks keyboard-down entry, Next, body newlines, Done, Keep editing and chooser insertion-position preservation, and keyboard dismissal plus visible rejection/expired-session messages after a long reply. The existing large-text case now types with the keyboard open; search checks submission dismissal without losing query/results. Native confirmation popovers hid the cancel-role Keep editing action, so it is now an explicit visible action. UI tests wait for the loaded fixture/toolbar and disambiguate native nested popover accessibility wrappers.

Validation uses Xcode 27.0 and iOS 26.1 simulators. The complete iPhone 17 Pro regression run passed **24 unit and 11 UI tests, zero failures** (`/private/tmp/fomio-keyboard-regression.xcresult`). A subsequently strengthened iPad test found that the multiline title inserted a newline despite its Next label. The title now uses a native single-line field; all **3 title-dependent iPhone UI tests passed, zero failures** (`/private/tmp/fomio-keyboard-title-iphone.xcresult`). The final iPad Pro 11-inch (M5) targeted run passed **2 UI tests, zero failures** (`/private/tmp/fomio-keyboard-title-ipad.xcresult`), covering long-reply rejection visibility and title/body focus, selection restoration, and the title keyboard Next key. Result bundles are local temporary artifacts. Earlier runs exposed the hidden Keep editing action, test-query ambiguity and a toolbar-readiness failure; the regression and corrected targeted runs together are the evidence; this is not a claim that every assertion ran against the final source in one suite.

Builds succeeded. Xcode emits the nonblocking AppIntents metadata-extraction warning for targets without AppIntents; simulator UI logs also emit an invalid-frame warning while focusing the native editor. No assertion failed in the final runs, but the warning's origin has not been isolated. Physical keyboard shortcuts/Full Keyboard Access, floating keyboards, VoiceOver focus announcements, real photo-picker cancellation/selection, rotation, RTL, background focus and resized iPad windows remain manual/device acceptance checks. These fixture results establish neither live posting/authentication nor exhaustive HIG compliance.

## Rebuilt editor — 2026-10-04

The editor now has a wrapping native title, TextKit rich/source projection, native block forms, and multiple protected retained photos. The earlier single-line/single-photo descriptions above record prior validation. Current implementation evidence and remaining gates are in [editor validation](editor-validation.md). The transport fix reached the site login page, the incoming callback fallback is wired, and Discourse's wrapped Base64 payload is decoded. A real issued-key callback, current-user lookup and live editor acceptance remain open. The expanded editor is not declared ready to ship.

## First App Store Connect upload — 2026-10-05

Distribution signing now uses automatic signing with team `LK9253R3XB` and bundle `com.fomio.mobile`, the same App Store Connect record (`6759279998`) previously used by the Expo app (last version 0.7.10). `project.yml` sets `MARKETING_VERSION` 0.8.0 and `CURRENT_PROJECT_VERSION` 1, `ITSAppUsesNonExemptEncryption = false`, and a privacy manifest (`Fomio/Resources/PrivacyInfo.xcprivacy`) declaring no tracking, no collected data types and no required-reason API use. The Expo camera, microphone and photo-library usage strings, push entitlement and `applinks:meta.fomio.app` associated domain were not carried over: the native app uses `PhotosPicker` and has no push or universal links. Increment `CURRENT_PROJECT_VERSION` for each later upload of the same version.

Build 0.8.0 (1) was archived with Xcode 27.0 (Release, generic iOS) and uploaded via `xcodebuild -exportArchive` (`app-store-connect`, destination `upload`); the upload succeeded and entered processing. The build has not been submitted for App Review. The live acceptance gates above (real sign-in callback, live posting/uploads, device accessibility) remain open and should be exercised on this TestFlight build before review.

Build 0.8.0 (2) was archived from commit `6b302a1` (category/topic IA and live API validation work) and uploaded on 2026-10-06; the upload succeeded and entered processing. It has not been submitted for App Review.

## Final audit corrections — 2026-10-07

The denied-refresh and removed-child cache findings now have passing acceptance regressions. Keyboard focus and Arabic phone rotation each pass twice; the final selected batch passes all 76 unit/contract tests and five UI journeys (zero failures; three live tests skipped). The catalogue search test is corrected for native Close/Cancel and passes; large-text and dark composer checks pass. A subsequent exact-context regression also passes: the final state run has 77 unit/contract tests and exact notification navigation passing, zero failures, three live tests skipped. Final Release simulator compilation succeeds with the existing unreachable fixture-branch warning. The prior Simulator audit gates are resolved for this source snapshot. This is focused acceptance, not a new full-device/live/distribution certification. [Current fix validation and remaining limits](validation/2026-10-07-audit-fixes/README.md).

Build 0.8.0 (3) was archived from commit `7f1ec12` (composer bar and category navigation fixes from `bee84a8`) and uploaded on 2026-10-08; the upload succeeded and entered processing.

Build 0.8.0 (4) was archived from commit `9a56c71` (topic cards, native category identities and hierarchy) and uploaded on 2026-10-15; the upload succeeded and entered processing.


## Visual composer build 0.8.0 (5) — 2026-10-15

Archived commit `067d8f0` (visual composer, optional Markdown mode, native Preview and draft recovery regression) with Xcode 27.0, Release/generic iOS, existing automatic signing team and bundle `com.fomio.mobile`. The archive's Info.plist confirms version 0.8.0 and build 5. The signed archive succeeded with the existing unreachable fixture-branch warning and the App Intents metadata-extraction notice.

Uploaded with `xcodebuild -exportArchive`, method `app-store-connect`, destination `upload`. Apple reported “Uploaded package is processing” and “Upload succeeded”; export exited successfully on 2026-10-15 at 21:22 Asia/Amman. This is an App Store Connect upload, not an App Review submission or public release. Archive/export logs are retained locally in `.build/release-0.8.0-5/` (ignored build artifacts).

Immediately preceding release, all four requested iPad Simulator composer journeys passed, including exact Markdown recovery after app termination/relaunch; see [editor validation](editor-validation.md#release-verification--2026-10-15). A separate “Composer release handoff” Claude Code thread was opened with the results and told to await further instructions without modifying or running anything. No pending localization worktree was merged and the unrelated topic-card review file was excluded from the release commit.


## Submission fixes — 2026-10-18 follow-up

Build 0.8.0 (7) includes dynamic native report flow, server-persisted Ignore/block and unblock with account-scoped content filtering, eligible self-deletion, policy/support links, callback registration and expanded privacy manifest. Live policies/contact and owner-approved reporting/Ignore/deletion limits updated. Connect native metadata and linked privacy labels saved. Final simulator regression:102passes,0failures,4opt-in live skips. Signed device archive and distribution IPA pass packaging/signature checks. Final member/device acceptance and listing assets remain; see [current submission packet](app-store-submission.md) and [validation](validation/2026-10-18-submission/README.md). Earlier build 6 blockers are historical.


## Build 0.9.0 (8) upload — 2026-10-20

Owner-authorized push and upload only; no App Review submission, automatic review submission or release was performed.

- **Source:** `59793c237305cf59cf6c1b292a9f98a15289da2f` on `main` (version commit on top of `293f3fa`: build 7 baseline, native notifications, composer transition fix, both audit-fix rounds, composer-bar test synchronization).
- **Verification before release:** two independent clean complete suites on that code, each 183 tests (176 passed, 7 opt-in skips, 0 failed) on iOS 27.0 simulators, independently audited ([validation](validation/2026-10-18-notifications/README.md), [clean-suite review](validation/2026-10-19-independent-audit/clean-suite-review.md)).
- **Version:** 0.8.0 is approved and closed for new builds (the earlier 0.8.0 (8) upload was rejected with “train version '0.8.0' is closed”, so no build 8 existed). `MARKETING_VERSION` 0.9.0, `CURRENT_PROJECT_VERSION` 8 in `project.yml`, regenerated project; packaged Info.plist resolves 0.9.0 (8).
- **Archive:** Xcode 27.1 (27A9275), Release, generic iOS, automatic signing, team `LK9253R3XB`: `ARCHIVE SUCCEEDED` (`.build/release-0.9.0-8/Fomio.xcarchive` in the integration worktree).
- **Export and checks:** app-store-connect export succeeded. IPA SHA-256 `ae178fe667b65dd681746cdc8b688c58faad0607380aa7f774759f4ee75093a5`. Signed by Apple Distribution: Ismail Zabalawi (LK9253R3XB); `codesign --verify --deep --strict` passes; entitlements: application identifier `LK9253R3XB.com.fomio.mobile`, `beta-reports-active` true, `get-task-allow` false, no push entitlement. `scripts/submission_preflight.py`: 20 PASS, no failures.
- **Upload:** `xcodebuild -exportArchive` with destination `upload` on 2026-10-20 at 00:00:34 +03. Apple reported “Uploading Fomio.ipa is complete … Uploaded package is processing … Upload succeeded.” Exit 0.
- **Processing:** not yet confirmed in App Store Connect by this session; the in-app browser was not signed in. Check TestFlight / Activity for 0.9.0 (8) before selecting it for a version.
- **Not established:** live APNs/relay delivery (unavailable by design; live Settings show alerts as not available), live Discourse notification acceptance, iPad and physical-device acceptance. App Review submission remains pending for the owner.

## Superseded build 0.8.0 (6) — upload record (history)

Build 0.8.0 (6) was archived from `31b4d53` (Reporting & Safety feature `6837b25`, recovery fixes `5d60931`) and uploaded on 2026-10-18 at 08:14 Asia/Amman with `xcodebuild -exportArchive` (app-store-connect, upload). Apple reported “Uploaded package is processing” and “Upload succeeded”. **Processing completion was not verified.** App Store Connect wasn't signed in for the uploading session, and on 2026-10-20 the owner chose to skip verification. Build 6 was never selected for review. `e3a6e04` later replaced it with the build 0.8.0 (7) baseline, and its safety sources are no longer on `main`.
# iPhone Duo preparation — 2026-10-18

The [Duo readiness record](iphone-duo-readiness.md) tracks the initial adaptive composer sizing change and source audit. Xcode 27.1 simulator compilation passes, but actual Duo fold/resize and vertical system bars remain unverified because no Duo simulator is provisioned. Phone composer rotation times out on iOS 26.1 with both the adaptive implementation and an original-sizing control; the earlier rotation passes above do not close this current gate. Resolve that baseline failure and complete the documented native matrix before claiming Duo readiness.

Later 2026-10-18 update: **four focused rotation regressions pass on iPhone 17 / iOS 27.0 with SDK 27.1**, after host recovery and correcting a new test's offscreen-row assumption. Home, reply-sheet controls, English Markdown writing and mixed Arabic/English text pass actual geometry checks. No production orientation workaround was needed. The removed iOS 26.1 runtime's original cause remains unverified. A Duo / iOS 27.1 simulator is now installed; its fold/vertical-bar matrix is still pending. [Final rotation evidence](validation/2026-10-18-rotation/README.md).

Duo reply follow-up: focused manual simulator acceptance passes on iPhone Duo / iOS 27.1. Fold/unfold preserves rich-text writing, selected range, native editor/focus and undo-manager availability; keyboard-visible transitions permit continued onscreen typing, with controls clear of keyboard/system bars. No production change was needed. Actual undo/redo actions, measured compact↔regular transitions and the wider accessibility/lifecycle/attachment matrix remain release gates. [Duo validation evidence](validation/2026-10-18-duo-reply/README.md).

Duo text-history update: Undo and Redo now pass after both fold directions in rich-text and multiline Markdown replies. Seven action outcomes were verified manually; a native XCTest probe passes the final pending Markdown redo (**1 passed, zero failures/skips**) following inconclusive simulator input. This closes the focused text-history gate without a production fix. Formatting/attachment history, measured compact↔regular transitions and the wider Duo matrix remain gates. [Detailed results](validation/2026-10-18-duo-undo/README.md).

Duo staged-photo update: **1 native UI journey passes, zero failures/skips**, combining automated Photos picker selection and assertions with four manual Device Hub fold transitions. One local photo and exact rich-text/Markdown writing survive both directions and Keep/reopen; retained image bytes remain readable. The upload failure is simulated, with Resume upload availability checked but no retry performed. This closes the focused local-photo retention gate; live/in-flight uploads, multiple photos, photo history/editing and process-termination recovery remain open. [Validation record](validation/2026-10-18-duo-photo/README.md).
