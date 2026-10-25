# Duo undo/redo and Markdown replies — 2026-10-18

Undo and redo both restore the expected text after folding and after unfolding, in rich-text and Markdown fixture replies. No production fix was needed. Seven outcomes were verified through native Device Hub UI; the final Markdown redo was verified with an opt-in XCTest probe after an inconclusive simulator action. These are eight focused action outcomes, not eight automated fold tests.

## Setup and results

Continued the [reply continuity journey](../2026-10-18-duo-reply/README.md) on the same iPhone Duo / iOS 27.1 simulator (`5325EFBF-C37B-47D8-AE20-41CCB4945844`), Xcode/SDK 27.1, Debug fixture topic 4182. The app process remained 35987 through the manual history tests and native inspection. No Post action or live mutation occurred.

[Source hashes](source-snapshot.json) identify the relevant dirty working-tree snapshot; unrelated existing changes were retained.

| Mode | Action after folding | Action after unfolding |
| --- | --- | --- |
| Rich text | Undo: `rich.qq` → `ric.qq`; Redo restores `rich.qq` | Redo restores `rich.qq`; Undo restores `ric.qq` |
| Markdown | Redo: `- q` → `- qq`; Undo restores `- q` | Undo restores `- q`; XCTest Redo restores `- qq` |

The rich-text prefix remains `Duo reply: ` throughout. Typed characters are separate undo entries in this editor, so undo removes the final `h`, not the whole word. The Markdown source remains exactly `**Duo** reply.\n\n- q` or `**Duo** reply.\n\n- qq`; bold markers, blank line, list marker and Markdown/Preview controls survive all tested transitions. [Exact observed before/after values](results.json).

Rich text was tested first with outer portrait/inner landscape, then inner portrait/outer landscape. Markdown uses outer landscape/inner portrait. Fold transitions were driven with Device Hub's Closed/Open buttons. The Markdown reply crossed the first unfolding with the software keyboard visible; it was explicitly hidden to access history controls when simulator input routing failed. This run does not claim every history action occurred with the keyboard visible. Captures show caret, source and accessible controls; a scrolled reply-context row is partly above the content viewport in the short outer landscape layout.

## Evidence and automation

- [Rich undo after folding](01-rich-undo-closed.png), [rich redo after unfolding](02-rich-redo-open.png), [rich redo after folding in landscape](03-rich-redo-closed-landscape.png).
- [Markdown undo after unfolding](04-markdown-undo-open.png), [Markdown redo after folding](05-markdown-redo-closed.png), [final Markdown redo after unfolding](06-markdown-redo-open.png).
- [Native pending-redo inspection](pending-redo-state.log): same editor `0x10e5c6400`, undo manager `0x115cf1180`, scene and first responder; `canRedo = 1`, `markedText = 0`, source ending `- q`, window 669×951 points, compact width. Debugger detached before the XCTest probe.
- [XCTest summary](test-summary.json): **1 passed, 0 failed, 0 skipped**. `FomioUITests.testDuoPendingMarkdownRedoProbe` attaches to the prepared running app, asserts exact Markdown source and Preview, taps the enabled Redo action and asserts the exact restored source. It does not launch a fresh reply or automate folding. Normal test runs skip this probe unless `FOMIO_DUO_REDO_PROBE=1`; prepare the fixture `**Duo** reply.\n\n- q` with a pending redo to `- qq` before running it. XcodeBuildMCP `testRunnerEnv` supplies that opt-in.

The probe inherits portrait requests in test setup/teardown; the inner display was already portrait. This is a native action on prepared history following manual folding, rather than an automated fold regression. Swift expected strings contain normal newline escapes (one backslash before each `n`), which evaluate to actual newline characters; native inspection independently confirms the multiline body. Independent read-only review checked the scoped claims, captures and test summary.

Machine-local result bundle: `/Users/ismailzabalawi/Library/Developer/XcodeBuildMCP/workspaces/Fomio-Swift-a437303753c0/result-bundles/test_sim_2026-10-18T19-37-17-286Z_pid74721_0d37c3d7.xcresult`. Build/test log copied to `.build/duo-undo-probe.log`.

## Input limitations and remaining scope

CUA coordinate clicks intermittently returned `noWindowsAvailable`; generic simulator taps sometimes reported success without changing the app. One final Markdown Redo menu action left source unchanged. Read-only inspection confirmed redo remained pending, and XCTest then successfully executed the same Redo against that prepared state. The first attempt is inconclusive; there is no reproducible app history defect in this evidence. The Markdown list was entered with native software-keyboard Return/dash/space/letter taps because the text-entry helper rejects multiline input. Native text selection was used instead of the helper's ineffective select-all replacement.

This verifies single-character undo/redo history across display changes in each mode. Undoing formatting, deleting blocks, attachments, deep multi-step history, switching modes with redo pending, IME composition, relaunch persistence, physical keyboard shortcuts, accessibility variants and physical hardware remain separate checks. Compact↔regular crossing is still not established by this run. No deployment or Discourse API behavior changed.
