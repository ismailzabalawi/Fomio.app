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
