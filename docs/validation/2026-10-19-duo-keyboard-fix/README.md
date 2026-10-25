# Duo keyboard diagnosis and candidate fix — 2026-10-19

**Keyboard visibility, clearance and actual onscreen typing pass compact → regular → compact. Regular-width More-menu history acceptance remains open.** The same focused reply/editor/undo manager survives the cycle. The resize UI test still fails menu interaction and must not be counted as a pass.

## Diagnosis

- Duo / iOS 27.1, Xcode/SDK 27.1. The [earlier captures](../2026-10-19-duo-size-classes/README.md) show disappearance and keyboard/bar overlap.
- Constant `.form` sizing did not fix disappearance and was reverted. The standalone SwiftUI rich-text prototype also lost its keyboard at 466×678 → 1000×678, without the reply sheet or composer bar.
- Toggling Device Hub → Device → Keyboard → **Simulate Hardware Keyboard** corrected disappearance in the standalone control. Subsequent composer expansion also retained a visible software keyboard. This is a simulator-mode observation, not an app change forcing software input when a hardware keyboard is intended.
- The floating keyboard does not reduce SwiftUI's bottom safe area. A passive keyboard-layout-guide reader, a constrained reader, and a window-guide reader failed regular-width clearance. The guide reported a full-width bottom strip even when Device Hub visibly showed a floating keyboard; see [abandoned guide state](abandoned-guide-state.log). Those implementations were removed.

## Current implementation

`ComposerKeyboardAvoidance` observes UIKit keyboard frame-change/hide notifications, filters screen mismatches and converts the reported screen frame through its own window into its local coordinates. It leaves full-width, bottom-docked keyboards to SwiftUI. For floating/undocked keyboards, it reports only overlap in the available composer bounds. The existing safe-area bar receives additional bottom padding. Hiding the keyboard clears that padding.

The original SwiftUI bar/menu, editor, controller and document-owned undo manager stay mounted. There are no device dimensions or fixed keyboard heights, forced responder resets, separate bar hosting controllers, or orientation workarounds. Sources: Apple's [keyboard frame notification](https://developer.apple.com/documentation/uikit/uiresponder/keyboardwillchangeframenotification) and [keyboard frame coordinate conversion](https://developer.apple.com/documentation/uikit/uiresponder/keyboardframeenduserinfokey?changes=_1).

## Regular-width evidence and limits

The final notification-based candidate was observed in Device Hub at **1000×678**, with `Trait draft`, a visible floating keyboard and the bar visibly above it. [Read-only native state](regular-native-state.log) records presenting horizontal size class **2**, editor size class **1**, `firstResponder=1`, selection `{11,0}`, `canUndo=1`, and pending `canRedo=1`. The More UIView frame is `{{709.8333,345},{47.6667,44.3333}}` in its 1000×678 window. This proves retained state and changed placement; it does not prove completed Redo/Undo or onscreen typing at that width.

The [resize accessibility trace](resize-accessibility-state.log) reports the main window as **333.3×226** and the same More button as **{{236.6,115},{15.9,14.8}}**—one third of the native coordinates. XCTest reports More as unreachable. Its screenshot attachment shows an inactive/background display rather than the rendered reply. These mismatches block using that test as regular-width input acceptance; they are not worked around by changing accessibility frames or multiplying tap coordinates in app code.

- Final diagnostic journey: **1 failed, 0 passed/skipped**, `test_sim_2026-10-19T14-11-38-050Z_pid62367_42291441.xcresult`. It reaches regular width with exact draft and keyboard existence, then fails the bar reachability expectation. It does not reach the return-to-compact/history steps.
- The native Device Hub screenshot was inspected in the conversation. No exported XCTest image is presented as composer evidence, since the exported regular-width image shows an inactive display.
- The Mac was unlocked for the follow-up below. Native mouse routing still returned `noWindowsAvailable`; direct simulator accessibility actions successfully delivered onscreen key presses. The earlier lock is historical, not the current blocker.
- General floating-keyboard dragging near the top and physical keyboard behavior remain unverified. Actual More-menu Undo/Redo **at regular width** is still blocked by simulator input routing.
- No live posting/upload, backend/API change, deployment, submission or commit occurred.

## Regression record

Earlier guide-reader candidates passed the three selected compact regressions, including a 3/3 pass in `test_sim_2026-10-19T13-58-40-954Z_pid62367_85f19496.xcresult`; this is historical and does not validate the final notification implementation. Some earlier repeats failed a second More-menu opening. A disconnected-reader control passed its single formatting test. Separate hosting-controller and constraint-based top-edge fallback experiments were removed.

Final notification implementation: **3 UI tests passed, 0 failed/skipped** in `test_sim_2026-10-19T14-15-03-916Z_pid62367_b89730a9.xcresult`: `testKeyboardBarNextAndKeepEditing`, `testLargestTextSelectionFitsBar`, and `testNativeFormattingCaretTypingSurvivesSourceSwitch`. This covers keyboard/focus recovery, largest-text bar reachability, docked-keyboard placement, and native formatting/Markdown switching. Build, Swift parse and `git diff --check` pass. It does not turn the failed regular-width journey into a pass.

## Unlocked follow-up: actual onscreen typing

One fixture reply remained open through **466×678 → 1000×678 → 466×678** in process 63120. Each input below used the visible keyboard's native accessibility action, without refocusing the editor. Capture Keyboard was briefly tested and restored to off; Cmd-Z did not change the draft and is not counted as an Undo.

| Checkpoint | Exact text | Root width class | Caret | Editor / undo-manager identity | Focus / history |
| --- | --- | --- | --- | --- | --- |
| [Compact before](typing-compact-before.log) | `Q` | 1 (compact) | `{1,0}` | `0x110fbb000` / `0x1146e48c0` | first responder, canUndo=1 |
| [Regular after key tap](typing-regular.log) | `Qq` | 2 (regular) | `{2,0}` | same / same | first responder, canUndo=1 |
| [Compact returned after key tap](typing-compact-after.log) | `Qqq` | 1 (compact) | `{3,0}` | same / same | first responder, canUndo=1 |

Keyboard and bar remain visible and clear in [regular-width capture](regular-input.png) and [compact-return capture](compact-return-input.png). For these screenshots, `simctl io ... screenshot --display=Resizable` captures the correct scene. Earlier numeric-display exports that showed a blank/inactive display are excluded from acceptance evidence.

A test-driver coordinate-conversion experiment reached regular width but failed to open More: **1 failed, 0 passed/skipped**, `test_sim_2026-10-19T14-23-07-733Z_pid62367_126efb64.xcresult`. The correction was removed; the driver retains the original reachability requirement and now logs concise frames. No accessibility or coordinate workaround was added to the app.

The normal-display attach-only `testTypedHistoryAfterWidthCycle` probe found the running reply with exact `Qqq` and keyboard existence, then failed to find Undo after tapping More: **1 failed, 0 passed/skipped**, `test_sim_2026-10-19T14-30-23-640Z_pid62367_cafe1106.xcresult`. No Undo or Redo is claimed. More interaction after a resize remains unresolved; a simulator coordinate/input problem is evidenced, but a menu lifecycle issue has not been ruled out.

## Remaining checkpoint

Resolve the remaining More-menu interaction after resizing and verify actual Undo/Redo at regular width and after compact return. Keep the failed full resize test as a failed result; the native typing cycle above closes only keyboard visibility, bar clearance, focused typing and retained editor/history identity for these measured widths.
