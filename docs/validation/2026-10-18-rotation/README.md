# Phone rotation diagnosis — 2026-10-18

Uses Build iOS Apps / XcodeBuildMCP, the [Duo preparation guide](https://developer.apple.com/iphone-duo/prepare/) and Apple's exported `app-resizability` skill. Existing project changes are preserved. No live community writes are needed for these fixture checks.

**Current result: four rotation regressions pass on iPhone 17 / iOS 27.0, built with Xcode/SDK 27.1.** Home, the reply sheet, English Markdown writing and mixed Arabic/English text rotate successfully. No production orientation workaround was needed. Earlier runtime/host failures below are historical; the original removed iOS 26.1 environment remains unverified.

## Source and runtime findings

- App-source audit covers all 28 Swift files, Info.plist and Debug/Release settings. No forced orientation, device-orientation layout branch, main-screen sizing or orientation override was found. ComposerDismissGuard adds a UIView, not a controller, and only guards dismissal.
- Generated launch screen is enabled; iPad declares all four orientations; iPhone declares portrait and both landscapes; there is no full-screen opt-out.
- LLDB on iPhone 18 Pro / iOS 27.0 confirms application orientation mask 26 (portrait plus both landscapes), root/presented-controller masks 30, and root `shouldAutorotate == true`. The app is foreground-active with an actual window. These observations rule out a missing landscape mask; they do not establish delivery of a rotation or explain every possible runtime lock.
- The iOS 26.1 runtime became unavailable during the investigation, ending the original device session. iOS 26.5 also became unavailable before an isolated control simulator could be created. No runtimes were removed by this task. Current runtime tests must be recorded separately from the earlier 26.1 failures.
- Apple's export command succeeds with access to Xcode: `/private/tmp/fomio-duo-skills/app-resizability/SKILL.md`. This supersedes the earlier failed export attempt. The skill's source-audit checks found no app API replacements necessary for this rotation task.

## Regression improvements

`FomioUITests.swift` now checks actual phone window shape in the Arabic Home test, verifies initial portrait before the English composer journey, and requests both landscapes with an asserted portrait transition between them. Returning to portrait avoids a false pass from asking for landscape-right when the window is already landscape-left. These are geometry checks; they are not Duo fold validation.

`testPhoneRotationKeepsHomeAndReplyReachable` isolates Home and the reply sheet without opening the formatting menu or entering text. This separates basic rotation from keyboard/menu interaction.

The iPad intentionally skips phone geometry assertions because rotating the device need not resize its window. Preservation results there must not be presented as actual rotation/resizing evidence.

## Execution evidence

The initial iOS 27.0 batch (`test_sim_2026-10-18T15-45-27-219Z_pid74721_3b1f9130.xcresult`) stalled on accessibility snapshots while looking for the Arabic composer Markdown menu item, before testing rotation. The MCP call timed out and its xcodebuild process was interrupted. This is not a completed rotation result.

Full bundles/logs are machine-local under `/Users/ismailzabalawi/Library/Developer/XcodeBuildMCP/workspaces/Fomio-Swift-a437303753c0/`. Physical-device and Duo fold/vertical-bar acceptance remain separate.

### Earlier execution blocker

The isolated iPhone 17 / iOS 27.0 attempt compiled the focused regression but stalled before executing it (`test_sim_2026-10-18T16-46-41-659Z_pid74721_a8d6c3da.xcresult`). Its xcodebuild process was interrupted; this task's simulator was shut down without erasing its data. The completed tool result reports runner launch failure / Mach error -308 (IPC server died); it does not report execution of the test method. The 90-second test limit does not bound time spent starting the runner. Final review tightened the focused test's control checks to wait for hittability after the window shape changes; those final assertion-only edits still need the post-recovery test run.

At about 19:50 Asia/Amman, `uptime` reported load averages **838.93 / 822.80 / 810.74**. Basic CoreSimulator process queries also stalled. Other simulator test jobs were running on this host; they were not interrupted by this task. This is evidence that the current environment cannot supply a reliable acceptance run, not proof of the original rotation failure's root cause.

No production orientation change has been made in this follow-up. Resume after host recovery: run `testPhoneRotationKeepsHomeAndReplyReachable` alone first. If Home rotates but the reply sheet does not, inspect sheet adaptation and the presented controller's lock state. If both fail, use a system-app rotation control before changing Fomio. Then run the English writing/Markdown and Arabic regressions, inspect attached landscape/portrait captures and confirm writing plus reachable controls. Keep the original iOS 26.1 failure open until reproduced or explicitly superseded by appropriately scoped acceptance.

## Post-recovery manual verification

After the user confirmed cleanup was complete and other jobs were paused, XcodeBuildMCP built and launched the app on **iPhone 17 / iOS 27.0**, linked against the **27.1 SDK**. The host's load spiked again and test-runner startup remained unreliable. A direct xcodebuild attempt also stalled; Memory Cleaner was temporarily suspended for that one experiment and then resumed. Its role in the host problem is not established. No other jobs or simulator data were removed.

Native Device Hub controls provided a working manual path. Safari displayed in landscape as a control. Fomio Home then displayed in landscape and rotated back to portrait while remaining open. An open reply containing `Rotation recovery check.` rotated to landscape and back to portrait without losing that text. Close, Post and the formatting bar stayed visible within the sheet. Software-keyboard, Markdown-mode and selection continuity are not established by this smoke check.

| Evidence | Result |
| --- | --- |
| Home landscape / portrait | Reading column and tab controls adapt to the available space. |
| Reply landscape / portrait | Identical reply text and visible sheet controls after rotation. |
| LLDB after foreground landscape | Window bounds `874 × 402`, effective orientation `landscapeRight`, scene orientation lock false, root lock preference false, root supported mask 30. |

Images are optimized simulator JPEG exports (800×368 landscape / 368×800 portrait), not native-resolution App Store assets. They contain fictional fixture content only.

The original iOS 26.1 rotation timeout is **not reproduced in these manual iOS 27.0 checks**. No production orientation workaround is justified by this evidence, and the missing 26.1 runtime prevents establishing its original root cause.

## Post-recovery regression correction

The warm direct test attempt (`.build/rotation-warm-20261018.xcresult`) successfully asserts Home portrait→landscape geometry. It then fails the added second-topic hittability check: topic 4182 is below the short landscape viewport. The focused test now checks the first fixture topic (4190) in landscape and returns to portrait before opening 4182. This corrects a test assumption; it does not change app behavior.

## Final automated acceptance

At **21:29 Asia/Amman on 2026-10-18**, the final direct xcodebuild run completed successfully: **4 passed, 0 failed, 0 skipped**. Device: iPhone 17 simulator, iOS 27.0 (`24A434`), UDID `F11F33D4-541C-411D-8230-4DD2DA76AFFD`; Xcode 27.1 (`27A9275`), SDK 27.1. [Machine-readable summary](test-summary.json).

| Regression | Verified behavior |
| --- | --- |
| `testPhoneRotationKeepsHomeAndReplyReachable` | Actual Home and reply-sheet landscape/portrait geometry; first feed row and composer Cancel remain tappable. |
| `testComposerKeepsWritingAndEditingModeAcrossLayoutChanges` | English reply text and Markdown mode survive landscape-left→portrait→landscape-right→portrait; continued typing and Keep draft succeed. |
| `testArabicHomeRotationKeepsFeedReachable` | Actual Arabic/RTL Home landscape and portrait geometry with the feed retained. |
| `testArabicComposerPreservesMixedTextAcrossModesAndRotation` | Mixed Arabic/English text survives mode switch and actual landscape rotation; Cancel is tappable inside the window. |

Result bundle: `/Volumes/Develop/Projects/Fomio Swift/.build/rotation-final-20261018.xcresult`; log: `.build/rotation-final-20261018.log`. The bundle contains the test-attached captures. Final test-source syntax parsing and `git diff --check` pass. Runtime logs include Xcode SDK-build parsing and duplicate accessibility-class warnings; they did not prevent this batch from passing and are not app compilation errors.

This closes the current **iOS 27.0 phone rotation reproduction/acceptance task**, without claiming the original iOS 26.1 root cause. Minimum-supported-OS/device checks, explicit software-keyboard/selection/undo continuity, and Duo fold/vertical-bar validation remain separate. The newly available Duo / iOS 27.1 simulator was not exercised in this rotation batch. No deployment target, version/build, signing, backend or submission state changed.
