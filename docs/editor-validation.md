# Native composer validation — 2026-10-04

Implementation base: `d802e389280bed5e07b11b5865d4eb462795e37d`, with working-tree changes. Read-only Discourse reference: `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. Xcode 27.0; iPhone 17 Pro and iPad Pro 11-inch (M5), iOS/iPadOS 26.1 simulators. Target: iOS/iPadOS 26+, SwiftUI shell and native UIKit/TextKit editor.

## Implementation and verification

- Raw Discourse text remains the persistence/submission authority. Supported formatting, links, quotes and blocks have editable native projections; unsupported syntax remains source-preserved with an Edit in Markdown action. The bounded codec is not an exhaustive nested Markdown parser.
- Native typing, selection formatting, caret typing attributes, paste, title wrapping/Next, undo/redo and mode switching are covered by tests, including mixed Arabic/English and emoji. Upload/preview updates do not create undo steps.
- Draft v2 retains multiple JPEGs in protected account-scoped storage, decodes v1 drafts, reconciles orphan files at startup, preserves submission locks and requires explicit resume after termination. Tests cover missing/corrupt files, disk failure, account isolation, duplicate server references, sequential uploads and cancellation/removal races.
- Native block forms validate authored syntax. Native attachment cards use TextKit geometry and bounded image thumbnails; retained/uploaded JPEG bytes are unchanged. Similar discussions, Onebox and plugin actions remain gated by verified capabilities; fixture availability is not live verification.
- All **55 unit/contract tests** passed on iPhone in the 15:39 UTC result. **16 iPhone UI journeys** passed across the final regression groups, including native block editing, retained failed photos, swipe protection, keyboard/focus recovery, source switching, formatting at the caret, posting outcomes, dark accessibility text and Arabic rotation. These counts describe recorded groups, not a single combined full-suite invocation.
- The final iPad run passed **59/59 checks**: all 55 unit/contract tests and four UI journeys for native forms, retained photos, caret formatting and Arabic mixed-text mode switching. This run includes the final bounded-thumbnail change. Across recorded iPad groups, five distinct targeted UI journeys passed, including keyboard/focus recovery. The iPad orientation request can leave the app window in portrait dimensions; this is not proof of landscape, Split View resizing or floating-keyboard acceptance.

## Captures

- [iPhone native code card](editor-captures/iphone-code-block.png)
- [iPhone Arabic keyboard-open landscape](editor-captures/iphone-arabic-landscape.png)
- [iPad native code card](editor-captures/ipad-code-block.png)
- [iPad Arabic app window](editor-captures/ipad-arabic-window.png)

The 2026-10-04 design snapshot preserves downloaded component/showcase sources and copied helper source alongside a rendered ScreenPack reference. It does not claim a complete offline archive. The previous snapshot is preserved. The accepted scope supersedes the mockup warning that unfinished photos are lost.

## Resolved regression findings

The native attachment implementation now verifies visible card content rather than accepting a generic attachment glyph. Explicit undo grouping with event grouping disabled resolved a unit-host undo exception. Native UIMenu controls removed the SwiftUI menu reparenting warning in final runs.

The iPhone Arabic keyboard-open rotation hang reproduced a SwiftUI status-bar presentation preference cycle. LLDB showed `AG::Graph::print_cycle` through `UIKitStatusBarBridge.shouldDeferToChildViewController` and UIKit trait propagation. An explicit composer status-bar preference, together with the final native presentation/editor implementation, passes the strengthened landscape check. Earlier failures are retained in their result bundles; they are not current acceptance evidence.

## Live member acceptance blocked

The configured `https://meta.fomio.app` normal authorization page reported that it could not issue user API keys before member credentials were entered. No member credential was saved or submitted, and no backend settings were changed. [Authorization evidence](editor-captures/live-user-api-disabled.png). A later transport fix corrected the malformed public-key query, and the native app now reaches the login page; the callback URL scheme, incoming-URL fallback and wrapped Base64 decoder are also fixed. See the [API diagnosis](discourse-api-reference.md). A real issued-key callback, upload, posting, moderation outcomes, previews and plugins remain unverified. A completed normal user-API-key authorization flow is required to finish these release checks.

## Release gates still open

Physical-device VoiceOver reading order/actions, Full Keyboard Access, Reduce Transparency/Motion, narrow supported phones, rendered contrast, iPad window resizing/floating keyboards and real Photos selection/cancellation remain acceptance work. Simulator accessibility-size and Arabic checks do not establish exhaustive accessibility compliance. Live member posting/upload/plugin acceptance is blocked as described above. **Do not ship the expanded editor until these gates pass.**

Static sRGB palette calculations (not rendered material/OS control measurements):

| Pair | Contrast |
|---|---:|
| accent light | 6.72:1 |
| secondary light fill | 5.94:1 |
| danger light | 5.47:1 |
| accent dark | 7.97:1 |
| secondary dark fill | 8.04:1 |
| danger dark | 7.63:1 |

## Result evidence

Local result bundles reside under `~/Library/Developer/XcodeBuildMCP/workspaces/Fomio-Swift-a437303753c0/result-bundles/`:

| Bundle | Evidence |
|---|---|
| `test_sim_2026-10-04T15-12-01-681Z_pid89196_a67c256e.xcresult` | 59 passing: then-current 53 unit/contract + 6 UI checks |
| `test_sim_2026-10-04T15-15-49-649Z_pid89196_489386c7.xcresult` | 10 passing iPhone UI checks, including strengthened Arabic rotation |
| `test_sim_2026-10-04T15-20-52-173Z_pid89196_3007e039.xcresult` | iPad 57 passing, one phone-aspect-ratio assertion failed; corrected to respect iPad window geometry |
| `test_sim_2026-10-04T15-28-24-962Z_pid89196_ecf2cc98.xcresult` | Corrected Arabic iPad window check passed |
| `test_sim_2026-10-04T15-32-04-964Z_pid89196_59447177.xcresult` | 55 unit/contract + Arabic iPhone UI passed |
| `test_sim_2026-10-04T15-39-16-731Z_pid89196_cb98f7c4.xcresult` | 55 unit/contract + Arabic and formatting-caret iPhone UI passed; no warnings/errors reported |

| `test_sim_2026-10-04T15-50-37-608Z_pid89196_909c17e1.xcresult` | Final iPad build: 55 unit/contract + four editor UI checks passed, zero failures |

Earlier failure evidence includes `test_sim_2026-10-04T14-04-35-796Z_pid89196_f16ed404.xcresult` (undo-host exception) and `test_sim_2026-10-04T14-08-15-142Z_pid89196_7657252c.xcresult` (four UI failures). Final passing groups above supersede those results for covered checks.

## Audit failure corrections — 2026-10-07

On iPhone 17 Pro / iOS 26.1, Arabic mixed text now survives actual landscape geometry after adding the base supported-orientation plist key. Direct title-to-body responder transfer passes Next, body newlines, continued typing and Keep editing in two runs. The final batch also passes largest-text selection-bar reachability, dark accessibility composer and catalogue search/quote/Markdown recovery. Search automation uses the system Close/Cancel control before sheet cancellation. Existing production catalogue refinements were preserved. [Results and scope](validation/2026-10-07-audit-fixes/README.md). Physical keyboard, VoiceOver and iPad resizing still require their own acceptance checks.

## Visual editing and Markdown preview — 2026-10-15

Base revision: `302973709b77b89c5272593cd45b1e7fea442d0e`; working-tree implementation. Raw Discourse markup remains the persistence and posting authority. The native projection now hides heading, quote and list prefixes, renders nested emphasis/links/inline code/strikethrough, and draws quote rules/list markers separately from editable text. Heading inline formatting is enabled. Formatting selected text serializes the edited runs; byte preservation applies to untouched source, opaque blocks, preview and mode changes, not to an explicitly reformatted run. UTF-16 start/end boundaries preserve Arabic/emoji and selections at hidden delimiters.

Return continues quotes/bullets/numbered/task items (clearing a continued checked task); an empty item exits its block. Backspace at the start of a styled line, including document start, removes its hidden prefix before deleting/joining content. Attachment instances retain identity and updated source positions through rerenders. Native marked-text composition finishes before the projection commits an edit.

More → Edit in Markdown remains an optional monospaced source mode; More → Rich text returns to visual editing. More → Preview works in either mode; source mode also provides a direct Preview control. Preview is a separate, selectable, read-only native view of the same draft with edit/remove controls hidden. Back restores editing focus/selection. Native preview performs no server-cooking request and does not mutate source or history. Structured blocks use native cards/forms, with readable table/poll/date summaries. Unknown blocks retain explicit source editing.

### Evidence

- iPhone 17 Pro / iOS 26.1, later list/newline pass: **94 passed, 4 live tests skipped** (full unit/contract target plus selection, checklist creation/toggle, and preview-return UI journeys). Result: `test_sim_2026-10-15T17-37-10-597Z_pid335_b0ed5e5d.xcresult`. This precedes the final capability-gating and numbered-list conversion checks.
- iPad Pro 11-inch (M5) / iPadOS 26.1: **30 passed** in the earlier projection/preview group (29 editor unit tests and preview-return UI), no failures/skips. Result: `test_sim_2026-10-15T17-33-35-931Z_pid335_b492e41d.xcresult`.
- iPhone 17 Pro / iOS 26.1: full unit/contract target plus four UI journeys passed **92 checks**, with **4 live tests skipped**. Result: `test_sim_2026-10-15T17-28-49-560Z_pid335_011950de.xcresult`.
- Earlier iPhone 17 Pro group: six UI journeys passed (Arabic mixed-text rotation, catalogue/quote insertion, heading transformation/cancellation, heading formatting, caret formatting through source switching, and visual/source/preview return). Result: `test_sim_2026-10-15T17-23-07-108Z_pid335_8a28b2e8.xcresult`.
- iPhone 16e / iOS 26.1: **31 checks passed** (29 editor/codec unit tests plus dark accessibility composition and the preview-return journey), no failures/skips. This includes the document-start Backspace handler. Result: `test_sim_2026-10-15T17-31-43-639Z_pid335_33bf5f94.xcresult`.

Result bundles live under `~/Library/Developer/XcodeBuildMCP/workspaces/Fomio-Swift-a437303753c0/result-bundles/`. Counts refer to these groups, not one combined suite. During development, regression tests caught stale attachment positions and a nested-emphasis selection-end mapping defect; both were fixed and passed the later groups. Final iPad verification passed **94 checks**, with **4 live tests skipped**, on iPad Pro 11-inch (M5) / iPadOS 26.1: the full unit/contract target plus checklist creation/toggle and visual/source/preview return. This run includes capability gating, numbered-list conversion, nested selection toolbar states and formatted-newline handling. Result: `test_sim_2026-10-15T17-39-06-758Z_pid335_c6bebf3a.xcresult`; build diagnostics reported no warnings/errors.

Visually inspected native [heading editing](validation/2026-10-15-wysiwyg/visual-heading.png) and [rendered preview](validation/2026-10-15-wysiwyg/preview.png), and [optional source mode](validation/2026-10-15-wysiwyg/markdown.png). Apple references consulted: [UITextView](https://developer.apple.com/documentation/uikit/uitextview), [TextEditor](https://developer.apple.com/documentation/swiftui/texteditor), and [text-input guidance](https://developer.apple.com/design/human-interface-guidelines/text-fields). Search excerpts were available; this is not a full HIG/accessibility acceptance claim.

### Limits

This remains a bounded native Markdown projection, not Discourse's complete cooking engine. Site/plugin-specific output, arbitrary nested block syntax, HTML and all CommonMark edge cases are not guaranteed to render identically; unknown blocks preserve their source and expose explicit Markdown editing. Numbered list is available in Turn into and insertion. Checklist creation and check controls are capability-gated: fixture support is explicit, while live checklist authoring remains disabled until verified. Existing checklist source remains preserved. Preview image display uses available local attachment data. Live plugin/cooking parity, physical-device IME/VoiceOver, clipboard format fidelity, floating keyboards and resized iPad windows remain acceptance work. No deployment or live write was performed.

### Release verification — 2026-10-15

On iPad Pro 11-inch (M5), iPadOS 26.1, all four requested composer journeys passed: selection formatting, checklist creation/checking, visual → Markdown → Preview → editing, and formatted draft recovery after terminating/relaunching the app. Recovery required explicit Keep draft and Resume; both the visual heading and exact raw `## Recovery check` were verified after relaunch. No live post was created. Result: `test_sim_2026-10-15T18-14-10-936Z_pid335_ecfc57e2.xcresult` (4 passed, 0 failures/skips). The new recovery UI regression is retained in the suite.

A new Claude Code thread, “Composer release handoff”, was created in Fomio.app with the test summary and instructions to wait without editing or running commands. Release preparation increments 0.8.0 to build 5; upload outcome is recorded in release readiness only after Apple confirms it.
