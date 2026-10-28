# Duo More-menu investigation — 2026-10-20

**Compact menu overflow is fixed and six history actions pass. Compact → regular → compact Undo/Redo acceptance remains open.** No completed history operation at regular width is established by this follow-up.

## Cause and retained fix

The pre-fix screenshot and [accessibility hierarchy](before-menu-hierarchy.txt) show that the second menu **is open** after successful Undo. Its visible collection starts with Undo at y=20; Redo is outside the visible menu viewport and absent from the accessible buttons. The menu is taller than the space above the keyboard. This establishes a menu-order/overflow issue in the compact reproduction, not a lost undo manager or a failure to reopen the menu.

`ComposerView.editorMenu` now puts Undo and Redo first. The existing native `ComposerMoreMenu` requests [fixed element ordering](https://developer.apple.com/documentation/uikit/uicontextmenuconfiguration/elementorder/fixed), keeping history at the visible start of the scrollable menu. The native control, menu refresh logic, adaptive rows, editor/history ownership and prior keyboard fix remain intact. No responder reset, extra hosting controller or coordinate workaround was added.

The final six-action compact regression passes with exact expected draft values and keyboard existence after every Undo/Redo. This closes the compact reproduction; the full regular-width journey remains pending below. Earlier experiments moving More outside `ViewThatFits`, replacing it with SwiftUI Menu, and using uncached deferred native menu content failed and were removed. An explicit priority-order trial made Undo reachable but lost the keyboard; it was replaced with fixed order before the passing run.

The new `testComposerMoreRefreshesUndoRedoAfterEachAction` captures screenshot/hierarchy attachments for missing menu actions. The opt-in resize journey requests portrait and detects window size as well as the potentially stale Application frame. Reachability and unobstructed keyboard requirements remain intact, with keyboard checks after each history action.

## Results

iPhone Duo `5325EFBF-C37B-47D8-AE20-41CCB4945844`, iOS 27.1, Xcode/SDK 27.1. Result bundles are machine-local under `~/Library/Developer/XcodeBuildMCP/workspaces/Fomio-Swift-a437303753c0/result-bundles/`.

| Bundle | Result and limits |
| --- | --- |
| `test_sim_2026-10-19T21-07-28-010Z_pid62367_809b16d4.xcresult` | Formatting/caret typing/Markdown switching: 1 passed. SwiftUI menu candidate before the final bar restructuring. |
| `test_sim_2026-10-19T21-13-44-462Z_pid62367_19b46d80.xcresult` | New repeated menu-history test: 1 passed, six actual Undo/Redo actions with expected draft values and keyboard existence. Before the final bar restructuring; not width-crossing acceptance. |
| `test_sim_2026-10-19T21-09-00-773Z_pid62367_3ffda5ef.xcresult` | Failed resize-detection wait. Read-only native inspection nevertheless measured 1000×678, presenting trait regular, focused body `Trait draft`, pending Undo/Redo. XCTest Application frame was stale. |
| `test_sim_2026-10-19T21-15-41-364Z_pid62367_c518933c.xcresult` | Removed bar-restructuring candidate compiled. Width detection reached regular, then failed the reachability/keyboard-clearance wait before Redo. 1 failed, 0 passed. |
| `test_sim_2026-10-19T21-26-14-117Z_pid62367_37ee145b.xcresult` | Removed SwiftUI candidate with final bar structure: 2 passed (formatting/Markdown and large text), 1 failed (second menu opening did not expose Redo after successful Undo). |
| `test_sim_2026-10-19T21-47-13-816Z_pid62367_bf7d5d99.xcresult` | Retained fix: 2 passed, formatting/caret typing/Markdown switching and dark accessibility-size composer reachability. |
| `test_sim_2026-10-19T21-43-16-747Z_pid62367_372b0e40.xcresult` | Retained fix, full width retry: initial compact Undo succeeds, then regular-width wait times out while Device Hub reports the Mac locked. 1 failed, no width cycle completed. |
| `test_sim_2026-10-19T21-41-42-882Z_pid62367_d5f54982.xcresult` | Retained fixed-order/history-first fix: 1 passed, six Undo/Redo actions with expected draft and visible keyboard after each. |
| `test_sim_2026-10-19T21-38-50-616Z_pid62367_f6b5363c.xcresult` | Removed priority-order trial: Undo reachable and correct text, but keyboard assertion fails; 1 failed. |
| `test_sim_2026-10-19T21-36-43-145Z_pid62367_4c52b928.xcresult` | Original-menu control with diagnostic attachments: 1 failed, missing Redo. Exporting all attachments revealed the clipped menu and established the compact cause. |
| `test_sim_2026-10-19T21-31-23-666Z_pid62367_014190fe.xcresult` | Removed native deferred-menu candidate: 1 failed repeated-history test. |
| `test_sim_2026-10-19T21-32-57-904Z_pid62367_837323c1.xcresult` | Removed native deferred-menu candidate avoiding redundant button configuration updates: 1 failed. |
| `test_sim_2026-10-19T21-34-48-667Z_pid62367_f253ec8c.xcresult` | Restored original native menu and original adaptive rows: same repeated-history failure, 1 failed. |
| `test_sim_2026-10-19T21-19-46-763Z_pid62367_ad62d2d0.xcresult` | Canceled during diagnosis/restart; no acceptance. Initial Undo eventually succeeded after a hit-point retry; no width cycle completed. |

The regular-width failure reports window `{{-331,273},{1000,678}}`, More `{{-88.5,362},{44,44}}`, keyboard `{{0,53},{669,253}}`, and `hittable=0`. These conflicting display/window coordinates prevent treating this as either a successful user interaction or proof of an app menu failure. The test retains its actual reachability requirement. Its resize wait now also checks window geometry because the Application frame can remain stale. The journey explicitly requests portrait before launching.

Selected console evidence is saved beside this record. No reparenting warning appeared in the two examined candidate logs; absence in those runs does not cover iOS 26.1.

## Environment blocker and next acceptance

Device Hub accessibility field actions work, but Return/mouse routing has been inconsistent. A read-only debugger inspection before the restart found the reply focused with `Trait draft`, `canUndo=1`, `canRedo=1`, and native window 669×951 despite conflicting displayed/automation geometry. The Duo simulator alone was shut down and restarted without erasing its data. `simctl bootstatus` then returned terminal status 3, **Data Migration Failed**; the Mac load average measured about 381. The subsequent build/run eventually succeeded and the app launched (PID 4400); the snapshot confirmed the fixture feed. The recovered session completed the three-test batch listed above. Native deferred-menu candidates also failed and were removed. The restored original implementation compiled and ran the baseline control above. A first compile attempt needed explicit main-actor isolation for its coordinator; that was corrected before the UI run.

Recover the Duo runtime and reliable Device Hub input first. The final compact history regression now passes. Formatting/Markdown and accessibility-size checks against the retained fix also pass (2/2); earlier experimental-source results remain historical. Complete the opt-in `testKeyboardAndHistoryAcrossManualWidths`: compact initial Undo, regular pending Redo/Undo plus new typing/Undo, then the same actions after compact return, checking the exact draft and visible unobstructed keyboard throughout. Do not close the gate from native `canUndo/canRedo` alone. Markdown width-crossing coverage remains a separate pending journey.

Device Hub explicitly reported the Mac locked again during the final width retry. An unlock request is pending; earlier user unlock confirmations do not establish the current desktop state.

## Unlocked follow-up later on 2026-10-20

The [independent Xcode audit and two width retries](../2026-10-20-xcode-duo-audit/README.md) supersede the locked-desktop blocker above. The Mac was unlocked, but both the original and a second Duo fail regular-width More reachability with inconsistent accessibility geometry. Neither completes regular history actions or compact return. The Xcode scene-local sign-in change has two additional passing focused tests.
