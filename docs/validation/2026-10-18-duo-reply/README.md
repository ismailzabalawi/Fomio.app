# iPhone Duo reply continuity — 2026-10-18

Focused native fixture acceptance passes for closed/open transitions while writing a rich-text reply, including software-keyboard-visible transitions. No production change was needed during this test. This is manual simulator testing with native runtime inspection, not an XCTest fold result or full Duo release acceptance.

## Environment

- Xcode 27.1 (`27A9275`), SDK 27.1; iPhone Duo / iOS 27.1.
- Simulator `5325EFBF-C37B-47D8-AE20-41CCB4945844`.
- Debug Fomio scheme, current working tree, built and launched through XcodeBuildMCP with `--fixture --ui-testing`; process 35987. Fixture topic 4182, “Oil vs. hardwax on a walnut desk top?”. No live writes or Post action.
- [Source snapshot](source-snapshot.json) records the base commit and relevant source hashes; pre-existing unrelated working-tree changes were retained.
- Device Hub's native Closed/Open controls drive actual display transitions. App window bounds change from 466×678 to 951×669 points. Both measured editor horizontal size classes are compact (`1`); this run does **not** establish a compact↔regular trait crossing.

## Results

| Check | Observed outcome |
| --- | --- |
| Closed → open with reply active | Exact text `Duo reply: closed.` and caret survive; the reply sheet adapts to the inner display. |
| Open → closed → open with nonempty selection | Selected word `closed` remains highlighted. Native range `{11, 6}` is identical before and after folding. Typing `unfolded` through XcodeBuildMCP replaces only that word, producing `Duo reply: unfolded.`. |
| Editor continuity | Native inspection before/after folding and after the final keyboard cycle finds the same `UITextView` (`0x10e5c6400`), scene session and undo manager (`0x115cf1180`). `isFirstResponder` remains true and `canUndo` remains true. Undo/redo operations and complete history contents were not exercised. |
| Open → closed → open with software keyboard visible | Keyboard remains visible and adapts to each display. A native onscreen `q` key tap immediately after each transition changes the body to `Duo reply: unfolded.q`, then `Duo reply: unfolded.qq`, without refocusing the editor. Final native caret is `{22, 0}`. |
| Safe areas | Reply context, text, Close/Cancel, Post and formatting controls remain visible; formatting stays above the software keyboard. Native Close moves into the outer display's right system area when closed. No clipping or overlap was observed in these captures. |

## Evidence

- Closed reply, opened reply.
- Selected word on inner display, same selection after folding.
- Open with keyboard, folded with keyboard, reopened with continued typing.
- Read-only LLDB snapshots: [before fold](open-selection-state.log), [after fold](closed-selection-state.log), [after repeated transitions and typing](reopened-state.log). Each debugger session detached before subsequent UI interaction.

The simulator has multiple displays. Default tool screenshots can capture an inactive display and appear black. These captures explicitly use `simctl io … screenshot --display=1` for the outer display (1398×2034 pixels) and `--display=3` for the opened inner display (2853×2007 pixels in this orientation). A black inactive-display capture is not evidence of an app failure.

Independent read-only review of captures 03–07 and the selection snapshots found no concrete clipping or safe-area defect and confirmed the compact-trait and undo-operation limits above.

Device Hub keyboard capture and generic hardware-key forwarding did not reliably insert text in this setup. Keyboard capture was restored to off. The visible keyboard was explicitly shown using Device → Keyboard → Toggle Software Keyboard; subsequent native onscreen key taps verified input after both transitions. Unsupported accessibility focus predicates were supplemented by read-only native inspection.

## Remaining scope

Markdown mode, mixed Arabic/English writing, long-document scrolling, attachments, undo/redo actions, partial-open poses, inner-display portrait, a measured compact↔regular trait change, lifecycle/draft recovery, accessibility variants and physical hardware remain separate acceptance items. The earlier phone rotation XCTest results remain in the [rotation record](../2026-10-18-rotation/README.md).
