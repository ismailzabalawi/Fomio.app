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

Update 2026-10-04: the full suite (25 unit/contract and 11 UI tests) passes on iPhone 17 Pro / iOS 26. A guest live run against `https://meta.fomio.app` confirmed feeds, categories, nested discussions, search and profiles. The browser sign-in error was traced to an unescaped `+` in the public-key query. The callback URL scheme and incoming-URL fallback are wired. After a user retest reached the app but did not sign in, the wrapped Base64 payload decoder was fixed; a fresh simulator build and all 60 unit/contract tests pass. A later simulator launch restored a previously authorized `FomioTester01` profile, establishing member credential restoration and live current-user lookup; the original issuance/decryption sequence and member actions were not observed end to end. Mobile signup entry and initial email validation were also verified; submission and activation are pending. Emoji images in cooked posts now render inline. See the live app check in [API verification evidence](discourse-api-reference.md).

Before 2026-10-04, no live requests were made and backend request specs were reviewed rather than executed. The backend remained unchanged at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. See [API verification evidence](discourse-api-reference.md).

Required before live acceptance: deployed base URL and relative root, version/settings and enabled nested replies, test accounts, callback registration and approved scopes, site-specific permissions/required fields, secure media and upload behavior, pending-author visibility and provable reconciliation evidence. Live “Check again” currently stays unresolved; it does not guess whether a post exists.

The bundle identifier is `com.fomio.mobile` (the existing App Store Connect record from the Expo app) and the app icon is the Icon Composer bundle `Fomio/Resources/AppIcon.icon` (2026-10-04, verified on the iOS 26 simulator home screen). Distribution still requires signing. Production incoming domains and entitlements remain pending; logical routing is implemented.

Native cooked-content rendering handles supported text, links, quotes, code and public images. Complex tables/embeds have an explicit link to the original post. The lightweight parser is not a complete Discourse HTML renderer; secure media and deployment-specific markup require integration validation.

Physical-device validation, full VoiceOver navigation, Reduce Motion/Transparency, Increase Contrast, RTL and iPad resizing remain release checks. Simulator large-text automation is partial evidence, not a complete accessibility audit. No offline sending queue, push transport, server draft sync, chat, private messaging or editing was added.

## Screen Pack parity — 2026-10-03

Every iPhone case in `Fomio MVP Screen Pack.dc.html` (P01–P05, S01–S17, R01–R16, A01–A03, X01–X06, N01–N02, A05) was compared against the versioned snapshot's `FomioPhone` component and implemented with fixture data matching the mockup seed (member `jonah.w`, nine discussions, Turning, restricted Makers Council, three notifications including an unavailable target, two saved items). Additions include the guest note, skeleton loading, 72-point trailing thumbnails that stack at accessibility sizes, directory latest previews and subcommunity chips, scoped-filter status and the “Search discussions for …” hand-off, the access-denied and unavailable-target screens, community headers with one primary action, discussion meta, avatars, own-post like counts, the ••• Save/Share menu, focus labels (“From your notification”, “Search match”, “Saved reply”, “Your reply”), the offline banner, action-specific sign-in sheets, an inline searchable “Post in” community field for global Create (replacing the earlier destination sheet), the composer context card, quote block, “Post in … Change/Required” row, photo status row, inline rejected/expired/offline/unconfirmed cards, keep-draft only after changes, Post again, the pending notice, toasts, and the tab badge.

Each state can be opened directly with the Debug `--preset <name>` argument ([development guide](development-guide.md)). Presets were captured on iPhone 17 Pro and iPad Pro 11-inch (M5) simulators running iOS 26.1, in light, dark and accessibility text sizes, and inspected against the mockup.

Deliberate differences: nested replies remain the approved adaptation of the mockup's chronological list, so exact-reply views offer “Show all replies” instead of “Show earlier posts (#1–#n)”. Native `.searchable`, menus, confirmation dialogs and system glass replace their CSS simulations. Per-post Save/Share are kept as a long-press context menu. Not implemented: the A04 iPad three-column list/discussion split (a proposal). Regular-width iPad uses the adaptive sidebar with a centered reading column. A06 compact-width behavior comes from the system TabView and still needs a real Split View resize check.

## Keyboard follow-up — 2026-10-04

Implemented a native single-line title field with distinct title/body focus, native Next/Done keyboard controls, interactive dismissal in composer/search/directory, retained search query on submission/navigation, Command-Return for guarded Post and Escape for protected Cancel. Native text selection is captured/restored through Keep editing and the community field; the Photos picker uses the same suspension path. Composer recovery messages receive scroll/accessibility focus, with Reduce Motion respected. Editing focus is cleared before sending and when inputs lock. No keyboard-height constants or custom focus navigation for ordinary buttons were introduced.

New regression coverage checks keyboard-down entry, Next, body newlines, Done, Keep editing and chooser insertion-position preservation, and keyboard dismissal plus visible rejection/expired-session messages after a long reply. The existing large-text case now types with the keyboard open; search checks submission dismissal without losing query/results. Native confirmation popovers hid the cancel-role Keep editing action, so it is now an explicit visible action. UI tests wait for the loaded fixture/toolbar and disambiguate native nested popover accessibility wrappers.

Validation uses Xcode 27.0 and iOS 26.1 simulators. The complete iPhone 17 Pro regression run passed **24 unit and 11 UI tests, zero failures** (`/private/tmp/fomio-keyboard-regression.xcresult`). A subsequently strengthened iPad test found that the multiline title inserted a newline despite its Next label. The title now uses a native single-line field; all **3 title-dependent iPhone UI tests passed, zero failures** (`/private/tmp/fomio-keyboard-title-iphone.xcresult`). The final iPad Pro 11-inch (M5) targeted run passed **2 UI tests, zero failures** (`/private/tmp/fomio-keyboard-title-ipad.xcresult`), covering long-reply rejection visibility and title/body focus, selection restoration, and the title keyboard Next key. Result bundles are local temporary artifacts. Earlier runs exposed the hidden Keep editing action, test-query ambiguity and a toolbar-readiness failure; the regression and corrected targeted runs together are the evidence; this is not a claim that every assertion ran against the final source in one suite.

Builds succeeded. Xcode emits the nonblocking AppIntents metadata-extraction warning for targets without AppIntents; simulator UI logs also emit an invalid-frame warning while focusing the native editor. No assertion failed in the final runs, but the warning's origin has not been isolated. Physical keyboard shortcuts/Full Keyboard Access, floating keyboards, VoiceOver focus announcements, real photo-picker cancellation/selection, rotation, RTL, background focus and resized iPad windows remain manual/device acceptance checks. These fixture results establish neither live posting/authentication nor exhaustive HIG compliance.

## Native composer rebuild — 2026-10-04 (working tree)

The new UITextView/TextKit projection replaces plain body/title inputs, with raw source authority, rich/Markdown switching, formatting/link forms, native undo, block attachment cards, wrapping-title Next/Done controls, and Unicode-aware mappings. Draft schema v2 decodes v1 quotes/photos into inline content. Multiple photos are retained in protected account-scoped storage, uploaded sequentially, resumed explicitly, and serialized inline without the old trailing append. Posting recovery and durable uncertainty locks are retained.

Native block forms, category templates, collapsed similar-discussion suggestions, sanitized native Onebox metadata, and conservative repository capabilities are implemented. Composer navigation uses one presentation state. English/Arabic resources and native dismissal-attempt handling are added. See [editor validation](editor-validation.md) for checks and release gates; this entry does not declare release readiness.

Final editor validation: 55 unit/contract tests pass on both recorded simulators; 16 iPhone UI journeys and five distinct targeted iPad journeys pass across recorded groups. The final iPad run includes the bounded photo-thumbnail change. A later transport fix reached the site login page; live member consent and editor acceptance remain open, as do physical accessibility/device checks. This supersedes the historical single-line title/single-photo implementation described above.


## Composer keyboard bar — 2026-10-05

Removed the separate UIKit Next/Done accessory row from title and body inputs. The existing SwiftUI formatting bar uses a bottom safe-area inset with zero spacing, placing it directly above the docked keyboard’s prediction row. Title navigation uses the keyboard’s Next key; body Return still inserts a newline and dragging dismisses input interactively.

Build and five targeted iPhone 17 Pro / iOS 26.1 fixture UI journeys passed across separate runs: large accessibility text, title/body focus and Keep editing, caret formatting/source switching, protected sheet dismissal, and native block editing. Existing tests were adapted to use native Next and drag dismissal instead of removed buttons. The block journey waits for menu readiness after restored keyboard focus. XCTest’s keyboard frame excludes QuickType; the screenshot verifies the visible boundary. Earlier test failures concerned the removed controls, an overly narrow geometry assertion, and gesture/menu timing. This is targeted docked-keyboard evidence, not a full-suite or floating-keyboard claim.

Evidence: [composer capture](validation/2026-10-05/composer-keyboard.png). Local result bundles under `~/Library/Developer/XcodeBuildMCP/workspaces/Fomio-Swift-a437303753c0/result-bundles/`: `test_sim_2026-10-05T07-42-36-110Z_pid67831_ad4aa207.xcresult` (large text), `test_sim_2026-10-05T07-46-11-544Z_pid67831_4b210df0.xcresult` (title/focus), `test_sim_2026-10-05T07-47-47-155Z_pid67831_8223dc41.xcresult` (formatting and protected dismissal), and `test_sim_2026-10-05T07-53-36-449Z_pid67831_6e0282cd.xcresult` (final block journey).


### Bar visibility follow-up — 2026-10-05

The formatting bar now collapses to zero height and becomes invisible, untappable and accessibility-hidden when the software keyboard is off-screen. Completed UIKit keyboard show/hide events drive this state, preserving the native More menu through transitional notifications. The native menu stays mounted while hidden, and toast spacing no longer reserves room for an absent bar.

Final iPhone 17 / iOS 26.1 targeted formatting journey passed: keyboard-down entry with a hidden bar, keyboard-up controls and alignment, caret Bold typing, Markdown switching, and hidden controls after dismissal. Result: `test_sim_2026-10-05T08-18-20-947Z_pid67831_7050b6d1.xcresult`. Protected swipe dismissal also passed in `test_sim_2026-10-05T08-11-37-980Z_pid67831_6f3f18eb.xcresult`. Earlier attempts exposed transition/menu timing and test harness interruptions; those are not passing evidence. The updated app also built and ran on iPhone 17 Pro / iOS 26.1. Floating keyboards and physical keyboard behavior were not exercised in this follow-up.

Captures: [keyboard hidden](validation/2026-10-05/composer-keyboard-hidden.png), [keyboard visible](validation/2026-10-05/composer-keyboard-visible.png).

## Floating composer bar (direction A) — 2026-10-05 (working tree)

Implemented the recommended contextual floating bar from [composer bar exploration](design/composer-bar-exploration.md#native-implementation-of-a--2026-10-05-working-tree): + opens a searchable Add block sheet that inserts after the captured block, the type chip turns the current block into Paragraph / Heading 2 / Heading 3 / Quote / Bulleted list in place, and a selection swaps in Bold · Italic · Link · Quote · Done. The bar replaces the keyboard-only accessory bar described above: it stays docked above the safe area with Show keyboard when the keyboard is hidden. ATX headings are now editable text in rich mode instead of opaque cards.

Found and fixed during validation: (1) icon targets were glyph-sized because the 44 pt frame sat outside the button; (2) unmounting the bar while the community list was open left the next text input without a software keyboard, so the bar now stays mounted and is only hidden; (3) after a pushed block/link/photo form closed with its keyboard still up, the composer did not receive the keyboard safe area and the bar sat behind the keys. Closing a pushed form now resigns its keyboard, and focus restore brings the body keyboard back. The block-form UI test now asserts the bar is above the keyboard. Its earlier More-tap retry suggests (3) predates this change.

UI test changes: the keyboard helper hides the keyboard with the bar's own control (the earlier drag also pulled a short reply sheet and opened Keep/Discard); block insertion goes through + and the sheet's search; a new test covers Turn into → Heading 2 and inserter Cancel returning to the same caret.

### Composer bar audit fixes — 2026-10-05

Implemented and verified on iPhone 17 Pro / iOS 26.1 simulator:

- Accessibility text sizes use Add block · More · Done/Keyboard, with formatting and transformations in More. SwiftUI icon targets stay 44 pt wide; semantic text can grow vertically. The largest system text size (`UICTContentSizeCategoryAccessibilityXXXL`) now keeps all three selection controls inside the screen and hittable. [Fixed capture](design/snapshots/2026-10-05-bar-audit/large-text-selection-fixed.png); [audit failure](design/snapshots/2026-10-05-bar-audit/large-text-selection.png).
- Add block Cancel preserves a deliberately hidden keyboard. Keyboard-up Cancel still restores the captured caret; choosing a new text block explicitly focuses its new caret.
- Bold, Italic and Link are disabled for heading/structured-block selections in More and omitted from the heading bar. Matching editor-command guards preserve source, selection and undo history, including selections spanning a heading and paragraph. Headings still render existing inline markup literally; full inline heading projection remains unimplemented.
- Development display settings now apply directly to the composer sheet. The previous `--accessibility-text` test passed with regular composer controls and did not establish large-text acceptance.

Validation: 28 selected checks passed (23 codec/native editor tests and five UI journeys), then three UI checks passed for the heading menu, hidden-keyboard Cancel with an explicit keyboard absence assertion, and dark accessibility text. These are two runs, 31 executions / 30 distinct tests, zero failures or reported warnings. Result bundles under `~/Library/Developer/XcodeBuildMCP/workspaces/Fomio-Swift-a437303753c0/result-bundles/`: `test_sim_2026-10-05T13-41-46-162Z_pid76838_6b582a15.xcresult` and `test_sim_2026-10-05T13-44-27-561Z_pid76838_7b68ed85.xcresult`. `git diff --check` passed. No backend contracts changed. Narrow phone widths, physical VoiceOver, RTL, iPad window/floating-keyboard behavior, IME and real Photos recovery remain outside this follow-up's verification.


## Compact category and topic screens — 2026-10-06

Implemented the user-approved [compact elevated direction](design/category-topic-claude-handoff.md) in native SwiftUI: a root/immediate-child directory with retained expansion and local filtering, backend category markers and optional light/dark logos, compact shared category headers with About and contextual New discussion, wrapping child chips, explicit aggregate feed scope, pinned/activity metadata, category-path discussion heading, authored OP, labeled Like/Save, per-post Reply/Quote, tinted quotes and outlined exact target. Large-text category headings stack identity above the name. Existing independent branch paging, permission revalidation, drafts and per-tab navigation remain in place. Category depth is independent of reply depth.

The adapter maps optional identity and site-default light/dark color tokens, effective reply sort and archived status. Prominent labels choose black/white by action-color luminance. The live fixture/deployment distinctions and remaining member-theme/media/catalog assumptions are recorded in [API reference](discourse-api-reference.md). The backend checkout was not modified.

Validation: Xcode 27.0, iOS/iPadOS 26.1. All **70 unit/contract tests passed** on iPhone 17 Pro. Across targeted runs, **seven distinct iPhone UI journeys and two iPad Pro 11-inch (M5) UI journeys passed**: directory expansion/About/exact-child creation; dark accessibility-size alternate-theme reachability; directory query/ancestor/Back retention; existing composer destination search, guest authorization without posting, notification #14 and reply/draft recovery. This is aggregated evidence, not one final complete-suite run. Initial category UI failures came from a launch helper waiting for a Home topic while the preset opened Communities; the helper was corrected and both journeys passed. Final cosmetic follow-ups include the directory guide, 14pt description, action contrast, large-text stacked identity and matching 16pt cooked/plain replies; builds and selected UI checks cover these refinements, not a complete rerun of the editor suite.

Result bundles under `~/Library/Developer/XcodeBuildMCP/workspaces/Fomio-Swift-a437303753c0/result-bundles/`:

- `test_sim_2026-10-06T16-31-57-629Z_pid7214_2d12ae93.xcresult`: 70 unit/contract + three existing UI passes, two helper failures.
- `test_sim_2026-10-06T16-35-26-571Z_pid7214_b8b8ad64.xcresult`: corrected two category UI passes.
- `test_sim_2026-10-06T16-38-24-003Z_pid7214_3461db5d.xcresult`: four iPhone UI passes after action/contrast refinements.
- `test_sim_2026-10-06T16-40-16-337Z_pid7214_9124341c.xcresult`: two iPad category UI passes.
- `test_sim_2026-10-06T16-42-36-841Z_pid7214_1f81d1ef.xcresult`: directory filtering and Back pass.
- `test_sim_2026-10-06T16-43-57-438Z_pid7214_60542ddd.xcresult`: large-text header refinement pass.

[Native captures](validation/2026-10-06-category-topic/README.md) show representative default/dark-large-text screens. Runtime hierarchy capture through MCP failed; XCTest supplied interaction evidence. Simulator checks do not establish physical VoiceOver, all contrast/motion/transparency settings, arbitrary long content/custom identity identifiers, narrow phones, iPad window resizing/floating keyboards or deployed member scheme/media behavior. No live member write was performed for this slice.


## Live category/topic integration — 2026-10-06

Category identity, default site palette, category/child feeds and exact topic/reply navigation were exercised against the configured Discourse site. Root paging and scoped child completion now prevent truncating lazy category previews; nonempty Saved responses now decode their `user_bookmark_list` wrapper. All **73 local unit/contract tests passed** (three live opt-ins skipped); separate live guest/member reads, the user-approved temporary topic/two-reply/Save/cleanup round trip and native live category→About→topic UI passed. Final readback confirmed test topics 1767/1768 unavailable to guests and absent from Saved. Three selected iPad journeys passed.

The full baseline had 92 passes and two failures: keyboard focus passed on later isolated/combined reruns; phone Arabic composer landscape remains reproducibly failing and is a release gate. No speculative orientation/presentation change was retained. Live burst tests encountered real 429s; separate spaced runs passed. Selected member scheme precedence, protected asset access, live uploads, pending-review/trust-level matrices and fresh/expired/revoked sign-in remain unverified. This is not a fully green release certification. [Full evidence and sanitized result summaries](validation/2026-10-06-live-api/README.md).
