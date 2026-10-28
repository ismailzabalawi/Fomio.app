# Compact → regular → compact reply test — 2026-10-19

**Partial acceptance.** The same open reply survives a measured compact → regular → compact presenting-window transition with its writing, caret, editor identity and pending history intact. Actual Redo and Undo work after the first round trip. Keyboard visibility and formatting-bar reachability do not pass consistently in the expanded simulator window. No production fix was made.

## Environment and scope

- iPhone Duo / iOS 27.1 (`5325EFBF-C37B-47D8-AE20-41CCB4945844`), Xcode/SDK 27.1, Debug fixture topic 4182. Process **80115** remains the same throughout. No live posting/upload or Post action.
- Device Hub **Resize mode**, width field **466 → 1000 → 466**, height **678**. These are resizable-scene transitions on the Duo simulator, not native Closed/Open fold actions. The composer stays open; no app relaunch, composer reconstruction or trait override is used.
- Read-only LLDB inspections measure the window root and editor traits separately. Every session detaches before further UI interaction. [Source snapshot](source-snapshot.json), [checkpoint results](results.json).
- Root width class is **compact (1) → regular (2) → compact (1)**. The editor remains compact inside the system form sheet, which is expected and must not be described as an editor-trait crossing.

## Results

| Check | Outcome |
| --- | --- |
| Writing and presentation | `Trait draft` survives both round trips. The page-sized compact sheet becomes a centered form at regular presenting width. |
| Editor/history identity | Same `UITextView` **0x10f4c3000**, undo manager **0x117c4abc0** and scene at all six inspections. `firstResponder = 1`; both Undo and pending Redo remain available after each return. |
| Caret | In the uninterrupted second cycle, selection stays exactly **{0, 0}** at all three checkpoints. This is an insertion caret, not a selected-word test. Earlier explicit input attempts moved the first cycle's caret; those are not resize-related preservation evidence. |
| Actual history actions | Before the first expansion, Undo removes the period from `Trait draft.`. After returning to compact and exiting Resize mode, native Redo restores `Trait draft.`, then Undo restores `Trait draft`. This verifies use of history created before the crossing. No history command is injected through LLDB. |
| Draft on disk | Autosaved version-2 fixture draft **0180A048-2E56-4400-95CD-EDE2A347BAD1**, same topic/parent and exact body `Trait draft`, is readable afterward. [Retained draft](retained-draft.json). No save/reopen or termination recovery is claimed. |
| Keyboard | Second cycle starts with the software keyboard visible. It disappears at regular width despite the editor remaining first responder, then reappears on return to compact without an explicit keyboard toggle between these three checkpoints. Keyboard continuity is **not accepted**. |
| Expanded controls | The first expanded capture shows a centered keyboard overlapping much of the bottom formatting bar. The second expanded capture shows the bar but no keyboard. This remains an unresolved simulator-observed layout/input issue. |

## Evidence and failed probe

- Uninterrupted second cycle: compact with keyboard, regular without keyboard, compact return with keyboard. These are native simulator captures from **display 5, Resizable**. Native displays 1/3 are not the active scene during Resize mode.
- First expanded keyboard overlap.
- Native state: [compact baseline](04-cycle-compact-state.log), [regular](05-cycle-regular-state.log), [compact return](06-cycle-compact-return-state.log). UI snapshots are saved alongside them; accessibility snapshots sometimes lag the visible keyboard, so the inspected native captures establish visibility.
- Added opt-in `PreparedReplyResizeUITests.testPendingHistoryAndKeyboard` in `FomioUITests.swift`. It attaches without launching, activating or requesting orientation, requires `Trait draft` with a pending redo and visible keyboard, then exercises Redo/Undo. Normal runs skip it unless `FOMIO_REPLY_RESIZE_PROBE=1`.
- The expanded-width probe **failed: 1 failed, 0 passed, 0 skipped**. It passed the initial text/keyboard checks, but tapping More computed hit point **{-1, -1}**, dismissed the keyboard and never opened Redo. [Test log](history-probe.log). This is not a passing automated history or resize result. Manual actions after return establish the scoped history result above.
- Machine-local result bundle: `/Users/ismailzabalawi/Library/Developer/XcodeBuildMCP/workspaces/Fomio-Swift-a437303753c0/result-bundles/test_sim_2026-10-19T13-01-57-386Z_pid62367_2fd8acf4.xcresult`.

Device Hub coordinate input intermittently returned `noWindowsAvailable`; full-screen Device Hub restored a working manual input path. Simulator taps sometimes reported success without changing the app. A native CUA Redo did change the exact body, and native Undo changed it back. No unverified tap is counted as an editing result. The host load average reached approximately **962** near the final checkpoint; app versus simulator/tooling responsibility for the keyboard findings is unresolved. DAP expression evaluation was unavailable, so inspections used CLI LLDB instead.

## Remaining acceptance

Reproduce the keyboard disappearance and overlap under normal host load and establish whether they originate in the app, Resize mode, or input tooling. Then run Undo/Redo and onscreen typing at **each** width with keyboard visible, including a redo pending on the return transition. Repeat in Markdown, with selected text, longer content, accessibility sizes, and native folds as separate scenarios. Do not close the overall compact/regular keyboard gate from the retained-state result alone.
