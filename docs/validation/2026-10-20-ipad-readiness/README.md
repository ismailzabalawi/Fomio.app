# Native iPad evidence

See [readiness and acceptance limits](../../ipad-readiness.md). These full-frame `XCUIScreen` captures use fictional fixtures and come from the iPad Pro 13-inch / iPadOS 26.0 run `e0169484`; source attachment names and SHA-256 hashes are recorded in [captures.json](captures.json).

- Wide list/detail: readable scope, selected discussion, community navigation and bounded reading content.
- Dark RTL accessibility chooser: full Arabic scope, scaled chooser text and Cancel; names remain server/fixture content.
- Native 375×500 window: actual iPadOS floating window, one-pane reading and retained search/topic selection. This is an interactive window with window controls, not an app-overview thumbnail.
- Portrait retained reply: exact text survives an observed landscape→portrait window change.

All seven selected UI journeys passed in this run. The full unit target had one bidi-marker test expectation mismatch and four opt-in live skips; the isolated expectation was corrected and passed afterward. This is not a single all-green combined test run. The later control-size/alignment refinement passed on mini with preserved captures below; see the readiness log.

No live write or backend change occurred. The initial four 13-inch captures do not establish physical input/accessibility acceptance or modal-active native resizing; later native editor resize evidence appears below. In later modal-active drag probes, iPadOS entered app overview; those thumbnails are not accepted narrow-window evidence.

Final iPad mini controls and accessibility chooser captures are preserved as `ipad-mini-final-reading.png` and `ipad-mini-final-rtl-chooser.png`. Their distinct source bundle and hashes are in [mini-captures.json](mini-captures.json). These predate the independent-window ownership change and do not establish multiwindow acceptance.

Native multiwindow creation and strengthened two-scene scope assertion passed in `8b6360f6`: new foreground scene and [two-scene AX hierarchy](ipad-independent-windows-hierarchy.txt) retain All communities and Finishing respectively. Provenance is in [independent-captures.json](independent-captures.json). Earlier isolated-deinit unit crashes from `f7a19adf` are recorded separately; subsequent seven focused contracts plus three normal iPad UI journeys passed in `90b9af58`. All eight window contracts passed in `8b6360f6`; its two modal-resize probes failed separately.

Native editor resize passed in `61f3c2af`: retained writing and caret after native expansion, with exact text plus a direct hardware-period event accepted without tapping/refocusing. [Provenance](active-resize-captures.json). The independent chooser resize probe failed to observe a wide window; its capture remains narrow with the chooser intact. Normal chooser rotation is separately verified.

Unresolved full-audit finding on iPadOS 27.0 (`a1a46678`): [exact detail-placeholder element report](ipad-audit-placeholder.txt) and element capture, with [hashes/provenance](audit-captures.json). The audit reports partially unsupported Dynamic Type for the detail placeholder description. It returns no issue exclusions; this is not a passing audit.

## Current-source acceptance and permission recovery

[Final current captures and hashes](current-captures.json) preserve the inspected narrow reading, Arabic AX3 chooser, new independent foreground window, [two native scene hierarchies](current-windows-hierarchy.txt), sidebar scope return, resized chooser and resized editor with retained caret/writing.

The [final mini matrix](final-ipad-matrix-summary.json) records17 passes and1 failure: the editor corner gesture did not expand the window. Its text/focus assertions were not reached. The [native Zoom follow-up](final-native-zoom-summary.json) passes both active chooser and editor cases with observed narrow→wide width changes and direct hardware input without refocus. All eight distinct functional iPad journeys have passing native evidence across those runs; no all-green combined result is invented.

The two-window permission bug is preserved as a [failed controlled repro](permission-repro-summary.json), followed by [22 focused passes](permission-focused-summary.json). The final [integration summary](final-integration-summary.json) has176 passes,0 failures and4 live skips; [per-target counts](final-integration-target-counts.json) are174 unit/contract passes plus2 native UI passes. Source identities for this acceptance are in [final-source-hashes.json](final-source-hashes.json). The two directions of denial stop automatic requests, explicit Retry can recover, private rows stay cleared, and same-account reauthentication refreshes each window's search identity.

The shared [final acceptance audit](../2026-10-20-adaptive-native/acceptance-audit.md) closes targeted assistive acceptance: [wide iPad native actions](../2026-10-20-adaptive-native/ipad-wide-voiceover-manual-observations.json) and [narrow 375×508 Arabic AX3/dark observation](../2026-10-20-adaptive-native/ipad-narrow-voiceover-final-summary.json), VoiceOver-off restoration and human confirmation of the single failure announcement. Full rotor/swipe traversal and physical-device certification remain unestablished. The unfiltered native predictive audits remain failed with minimal native reproductions; their attachments are preserved, not relabeled as passing audits. iPad preparation is complete at the qualified functional scope documented in the readiness report.
