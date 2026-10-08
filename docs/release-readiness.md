# Validation and release readiness

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

Out of MVP: offline sending queue, server drafts, push transport, Hot/tracked feeds, notification-level controls, private messages/chat, AI, advanced settings, editing and formatting modes.

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
