# Native implementation status — 2026-10-03

## Delivered

Developer handoff: [architecture](architecture.md), [development guide](development-guide.md), [flows/recovery](flows-and-recovery.md), and [release readiness](release-readiness.md).

The first native milestone is implemented in `Fomio.xcodeproj`: an iOS/iPadOS 26+ SwiftUI app with Home → Community → Discussion → Composer, explicit development fixtures, independent tab stacks, bounded nested threads and protected account-scoped local draft recovery. Additional MVP screens include local community filtering, discussion search, replies/mentions notifications, member profiles, Saved, Drafts and sign-out.

Native bars, menus and sheets use system styling. The purple/white and AMOLED palette, provided wordmark and licensed sample imagery come from the versioned design export. Content columns are capped at 620 points and the tab shell adopts a sidebar on regular-width iPad. Dynamic Type, semantic labels and 44-point controls are used throughout. English SwiftUI strings are localization-ready; translations are not included.

Posting distinguishes publication, pending review, rejection, expired authorization and uncertainty. Unconfirmed records stay locked; manual retry requires a duplicate warning. Upload failure/cancellation is independent of writing. Kept drafts warn about unfinished photos and offer both recovery choices. Account sign-out removes that account’s drafts and credential. Fixtures provide offline, upload failure and unsupported nested capability controls under Me.

The repository layer includes source-informed Discourse adapters and browser per-user authorization with Keychain storage. These have not been accepted against a deployed instance. Release builds never silently show fixture data when configuration is absent.

## Run and review

Open the Fomio scheme in Xcode and select an iOS 26+ simulator. `project.yml` regenerates the project with XcodeGen. Debug defaults to labeled fixtures when no live configuration is available. Optional development arguments:

- `--fixture`, `--guest`, `--live`
- `--post-outcome published|pending|rejected|expired|unconfirmed`
- `--upload-fails`, `--dark`, `--accessibility-text`, `--rtl`

Fixture data and authorization are fictional. The UI tests isolate draft storage using a random namespace. Simulator signing is ad hoc for Keychain testing, with no production signing configuration implied.

## Validation

Tests cover account isolation and sign-out, durable recovery, persistence failure, submitting-to-unconfirmed restoration, photo recovery, pending/uncertain locks, publication navigation, guest intent, nested pagination/context, missing capability, relative URL roots, optional DTO fields, authorization/rate-limit meanings, search exact targets, moderation response separation, native content blocks and actual Keychain round-trip.

Native UI automation covers the core journey, guest authentication without posting, exact notification reply, missing live configuration, uncertain retry warning, failed-photo recovery and dark accessibility text. Results: **24 unit tests and 8 UI tests passed across the full regression run and targeted reruns** on iPhone 17 / iOS 26.1. The original regression run had a dismissal-timing failure in photo recovery; the test now waits for the composer to dismiss and passes. The added search-return test exposed a hidden search field; explicit native drawer placement corrected it and the targeted rerun passed. No build warnings were reported by the final build/test tools.

Native launches succeeded on iPhone 17 and iPad Pro 11-inch (M5), iOS 26.1. Captures were visually inspected: [iPhone Home](validation/2026-10-03/iphone-home.jpg), [iPad Home](validation/2026-10-03/ipad-home.jpg). The iPad capture shows the system sidebar toggle, adaptive top tabs and centered content. Interactive iPad resizing and complete sidebar/composer validation remain pending.

XcodeBuildMCP result bundles are under `/Users/ismailzabalawi/Library/Developer/XcodeBuildMCP/workspaces/Fomio.app-1d5e7f2fae17/result-bundles/`:

- `test_sim_2026-10-03T16-17-33-151Z_pid6930_b751c333.xcresult`: all 24 unit tests and six UI tests passed; photo test failed before its timing fix.
- `test_sim_2026-10-03T16-19-25-081Z_pid6930_41ae622b.xcresult`: corrected photo recovery passed.
- `test_sim_2026-10-03T16-23-48-268Z_pid6930_6285cdb6.xcresult`: search query/results return passed.

The MCP runtime hierarchy capture returned no usable phone targets and failed on iPad; native XCTest provided interaction verification instead.

## Release gates and practical limits

Update 2026-10-04: the full suite (25 unit/contract and 11 UI tests) passes on iPhone 17 Pro / iOS 26. A guest live run against `https://meta.fomio.app` confirmed feeds, categories, nested discussions, search and profiles. Browser sign-in is blocked because the site renders its generic "unable to issue user API keys" error; the cause is unconfirmed. Emoji images in cooked posts now render inline. See the live app check in [API verification evidence](discourse-api-reference.md).

Before 2026-10-04, no live requests were made and backend request specs were reviewed rather than executed. The backend remained unchanged at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. See [API verification evidence](discourse-api-reference.md).

Required before live acceptance: deployed base URL and relative root, version/settings and enabled nested replies, test accounts, callback registration and approved scopes, site-specific permissions/required fields, secure media and upload behavior, pending-author visibility and provable reconciliation evidence. Live “Check again” currently stays unresolved; it does not guess whether a post exists.

The bundle identifier is `com.fomio.mobile` (the existing App Store Connect record from the Expo app) and the app icon is the Icon Composer bundle `Fomio/Resources/AppIcon.icon` (2026-10-04, verified on the iOS 26 simulator home screen). Distribution still requires signing. Production incoming domains and entitlements remain pending; logical routing is implemented.

Native cooked-content rendering handles supported text, links, quotes, code and public images. Complex tables/embeds have an explicit link to the original post. The lightweight parser is not a complete Discourse HTML renderer; secure media and deployment-specific markup require integration validation.

Physical-device validation, full VoiceOver navigation, Reduce Motion/Transparency, Increase Contrast, RTL and iPad resizing remain release checks. Simulator large-text automation is partial evidence, not a complete accessibility audit. No offline sending queue, push transport, server draft sync, chat, private messaging or editing was added.

## Screen Pack parity — 2026-10-03

Every iPhone case in `Fomio MVP Screen Pack.dc.html` (P01–P05, S01–S17, R01–R16, A01–A03, X01–X06, N01–N02, A05) was compared against the versioned snapshot's `FomioPhone` component and implemented with fixture data matching the mockup seed (member `jonah.w`, nine discussions, Turning, restricted Makers Council, three notifications including an unavailable target, two saved items). Additions include the guest note, skeleton loading, 72-point trailing thumbnails that stack at accessibility sizes, directory latest previews and subcommunity chips, scoped-filter status and the “Search discussions for …” hand-off, the access-denied and unavailable-target screens, community headers with one primary action, discussion meta, avatars, own-post like counts, the ••• Save/Share menu, focus labels (“From your notification”, “Search match”, “Saved reply”, “Your reply”), the offline banner, action-specific sign-in sheets, a destination chooser before global Create, the composer context card, quote block, “Post in … Change/Required” row, photo status row, inline rejected/expired/offline/unconfirmed cards, keep-draft only after changes, Post again, the pending notice, toasts, and the tab badge.

Each state can be opened directly with the Debug `--preset <name>` argument ([development guide](development-guide.md)). Presets were captured on iPhone 17 Pro and iPad Pro 11-inch (M5) simulators running iOS 26.1, in light, dark and accessibility text sizes, and inspected against the mockup.

Deliberate differences: nested replies remain the approved adaptation of the mockup's chronological list, so exact-reply views offer “Show all replies” instead of “Show earlier posts (#1–#n)”. Native `.searchable`, menus, confirmation dialogs and system glass replace their CSS simulations. Per-post Save/Share are kept as a long-press context menu. Not implemented: the A04 iPad three-column list/discussion split (a proposal). Regular-width iPad uses the adaptive sidebar with a centered reading column. A06 compact-width behavior comes from the system TabView and still needs a real Split View resize check.

## Keyboard follow-up — 2026-10-04

Implemented a native single-line title field with distinct title/body focus, native Next/Done keyboard controls, interactive dismissal in composer/search/directory, retained search query on submission/navigation, Command-Return for guarded Post and Escape for protected Cancel. Native text selection is captured/restored through Keep editing and the community chooser; the Photos picker uses the same suspension path. Composer recovery messages receive scroll/accessibility focus, with Reduce Motion respected. Editing focus is cleared before sending and when inputs lock. No keyboard-height constants or custom focus navigation for ordinary buttons were introduced.

New regression coverage checks keyboard-down entry, Next, body newlines, Done, Keep editing and chooser insertion-position preservation, and keyboard dismissal plus visible rejection/expired-session messages after a long reply. The existing large-text case now types with the keyboard open; search checks submission dismissal without losing query/results. Native confirmation popovers hid the cancel-role Keep editing action, so it is now an explicit visible action. UI tests wait for the loaded fixture/toolbar and disambiguate native nested popover accessibility wrappers.

Validation uses Xcode 27.0 and iOS 26.1 simulators. The complete iPhone 17 Pro regression run passed **24 unit and 11 UI tests, zero failures** (`/private/tmp/fomio-keyboard-regression.xcresult`). A subsequently strengthened iPad test found that the multiline title inserted a newline despite its Next label. The title now uses a native single-line field; all **3 title-dependent iPhone UI tests passed, zero failures** (`/private/tmp/fomio-keyboard-title-iphone.xcresult`). The final iPad Pro 11-inch (M5) targeted run passed **2 UI tests, zero failures** (`/private/tmp/fomio-keyboard-title-ipad.xcresult`), covering long-reply rejection visibility and title/body focus, selection restoration, and the title keyboard Next key. Result bundles are local temporary artifacts. Earlier runs exposed the hidden Keep editing action, test-query ambiguity and a toolbar-readiness failure; the regression and corrected targeted runs together are the evidence; this is not a claim that every assertion ran against the final source in one suite.

Builds succeeded. Xcode emits the nonblocking AppIntents metadata-extraction warning for targets without AppIntents; simulator UI logs also emit an invalid-frame warning while focusing the native editor. No assertion failed in the final runs, but the warning's origin has not been isolated. Physical keyboard shortcuts/Full Keyboard Access, floating keyboards, VoiceOver focus announcements, real photo-picker cancellation/selection, rotation, RTL, background focus and resized iPad windows remain manual/device acceptance checks. These fixture results establish neither live posting/authentication nor exhaustive HIG compliance.

## Native composer rebuild — 2026-10-04 (working tree)

The new UITextView/TextKit projection replaces plain body/title inputs, with raw source authority, rich/Markdown switching, formatting/link forms, native undo, block attachment cards, wrapping-title Next/Done controls, and Unicode-aware mappings. Draft schema v2 decodes v1 quotes/photos into inline content. Multiple photos are retained in protected account-scoped storage, uploaded sequentially, resumed explicitly, and serialized inline without the old trailing append. Posting recovery and durable uncertainty locks are retained.

Native block forms, category templates, collapsed similar-discussion suggestions, sanitized native Onebox metadata, and conservative repository capabilities are implemented. Composer navigation uses one presentation state. English/Arabic resources and native dismissal-attempt handling are added. See [editor validation](editor-validation.md) for checks and release gates; this entry does not declare release readiness.

Final editor validation: 55 unit/contract tests pass on both recorded simulators; 16 iPhone UI journeys and five distinct targeted iPad journeys pass across recorded groups. The final iPad run includes the bounded photo-thumbnail change. Live member authorization is blocked by site user-API-key issuance; physical accessibility/device acceptance remains open. This supersedes the historical single-line title/single-photo implementation described above.
