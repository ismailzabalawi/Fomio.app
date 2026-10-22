# Duo photo reply continuity — 2026-10-18

**Pass: 1 native UI test, 0 failures, 0 skips.** A photo selected through the system Photos picker survives folding and unfolding in rich-text and Markdown replies, then Keep draft → Drafts → reopen. No production fix was needed.

## Environment and procedure

- Xcode/SDK 27.1; iPhone Duo / iOS 27.1, simulator `5325EFBF-C37B-47D8-AE20-41CCB4945844`.
- Debug Fomio scheme, isolated fixture namespace, topic 4182. Launch arguments `--fixture --ui-testing --upload-fails`. No live upload or Post action.
- Imported the existing `Fomio/Resources/fixture-photo.jpg` using `simctl addmedia`, selected its walnut image through the native picker and tapped Done. This exercised Add photo, picker transfer and JPEG retention, rather than the app's Sample photo shortcut.
- XCTest handles writing, picker selection, assertions, saving and reopening. The agent drives Device Hub's Closed/Open controls when the test emits each `DUO_PHOTO_WAIT_*` checkpoint. Actual scene geometry changes from outer landscape 678×466 to inner portrait 669×951 points and back. Four transitions are verified: rich open/closed, then Markdown open/closed. A width-only assertion would miss this pose combination; the test accepts a substantial width **or height** change.

## Verified outcomes

| Check | Outcome |
| --- | --- |
| Initial attachment | `Photo fold draft.` remains with one photo. Simulated upload failure exposes one Retry upload action. |
| Rich-text unfold and fold | Exact native editor value, including the attachment placeholder, remains unchanged. One Retry upload action remains; Post stays disabled after the native sheet settles. |
| Markdown unfold and fold | Exact full source remains unchanged, with one local attachment reference: `fomio-attachment://06259CA4-6219-4FC3-9EBF-1615A7BCAA75`. Markdown Preview remains available. |
| Keep and reopen | The saved reply opens from Me → Drafts. It has one Resume upload action and the identical text and attachment reference after switching to Markdown. |
| Retained photo bytes | After the passing test, the corresponding local JPEG still exists: **180,708 bytes**, decoded and visually inspected as the same walnut fixture image (960×640). [Retained file](retained-photo.jpg), [hash and storage evidence](retained-photo.json). This is a post-test read, not a before/after byte comparison. |

The recovered Resume upload state also exercises `ComposerState`'s existing restoration check: missing or undecodable retained photo bytes become `.missing`, rather than `.retained`. Saving/reopening here occurs within the app session; it is not a process-termination recovery test.

## Evidence

- [Native rich-text closed](01-rich-closed.png) and [opened](02-rich-open.png) show the actual photo thumbnail during the earlier diagnostic run with the same fixture and production source.
- [Markdown closed](03-markdown-closed.png) and [opened](04-markdown-open.png) are explicit-display native captures from the final passing run, showing the same attachment UUID.
- [Test summary](test-summary.json): `FomioUITests.testDuoPhotoReplyAcrossManualFolds`, 1 passed, 0 failed, 0 skipped. [Source snapshot](source-snapshot.json).
- Machine-local result bundle: `/Users/ismailzabalawi/Library/Developer/XcodeBuildMCP/workspaces/Fomio-Swift-a437303753c0/result-bundles/test_sim_2026-10-18T20-30-42-495Z_pid74721_1f4a8daf.xcresult`; build/test log copied to `.build/duo-photo-final.log`.

The bundle contains six XCTest screenshot attachments. Some outer-display `app.screenshot()` exports have incorrect cropping/mapping, so they are not used as full-layout visual proof here. The linked native captures explicitly use `simctl io … screenshot --display=1` (outer) and `--display=3` (inner).

Independent read-only review confirmed the scoped assertions, retained image and native Markdown captures; no concrete fold-related layout defect was identified. Geometry assertions alone could also pass after rotation; the Device Hub actions recorded in this run establish that these four changes were folds.

## Repeating and limits

Opt in with XcodeBuildMCP `testRunnerEnv: {"FOMIO_DUO_PHOTO_TEST":"1"}` and select `FomioUITests/FomioUITests/testDuoPhotoReplyAcrossManualFolds`. Start with Duo closed, provision the fixture as the first picker grid image, and drive each requested fold within 120 seconds. Normal test runs skip this interactive journey. Picker identifiers reflect the inspected iOS 27.1 runtime.

Earlier harness attempts timed out before selection, queried collection cells instead of the picker's image elements, or queried Post immediately during a sheet transition. A failed prepared-state continuation also found the app no longer running. The final run starts fresh, selects the image through the actual image element, and waits for Post using its identifier across accessibility roles. No app workaround was introduced for those harness findings.

This closes focused local photo/draft retention acceptance. Live upload success, folding during an in-flight upload, multiple photos, photo editing/removal/undo, process-termination recovery, photo-picker cancellation, compact↔regular trait crossing, accessibility variants and physical hardware remain separate checks.
