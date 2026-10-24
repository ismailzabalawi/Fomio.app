# Duo windows + notifications merge — 2026-10-22

Branch `claude/duo-notifications-merge`, merging `duo-adaptive-reading` (`b92b29d`) into `main` (`27db168`). Not pushed or uploaded.

## What changed

- Notification inbox, device alert setup and duplicate-tap filtering moved into `AppWindows`; see [architecture](../../architecture.md#notifications-with-several-windows--2026-10-22).
- Taps go to the most recently used window (key or active), and are held until a window finishes launching.
- A rejected key on a tap now expires every window; only the tapped window asks to sign in.
- Duo's feed geometry and image loader replace main's equivalents. Main's behind-the-bar geometry test is kept against Duo's model.
- Two uncommitted Duo search-field edits are carried as their own commit (`e4e621f`).

## Tests added

`FomioTests/MultiWindowNotificationTests.swift` (9 unit tests) and `FomioUITests/MultiWindowNotificationUITests.swift` (3 iPad UI tests, which skip unless both windows are on screen together).

## Results — 2026-10-24/25

Xcode 27, reused simulators per AGENTS.md: iPhone 17 and iPad Pro 11-inch (M5), both iOS 27.0. Each failure was checked against unmodified `main` (`27db168`) and Duo (`b92b29d`) on the same simulator.

| Run (commit `e61c93f`) | Passed | Failed | Skipped |
|---|---|---|---|
| Unit/contract, iPhone 17 (earlier, `64f3576`) | 214 | 0 | 4 live opt-in |
| Full suite, iPhone 17 | 291 | 2 | 35 |
| Full suite, iPad Pro 11-inch (M5) | 283 | 13 | 32 |

All 9 `MultiWindowNotificationTests` pass on both devices.

**Failures that also occur without the merge**

- 11 iPad UI tests fail identically on unmodified Duo: four feed-appearance “More discussions” reachability tests; the chooser audit; the composer catalogue, “More” undo/redo, selection formatting, dark accessibility and inserter-cancel composer tests; the native formatting caret test; the wide-sidebar test.
- `testCommunityChooserAccessibilityAudit` fails on Duo on iPhone too (line 560: Return in the filter does not dismiss the keyboard). The carried search-field edit in `e4e621f` does not fix it.

**Intermittent**

- `testNativeFormattingCaretTypingSurvivesSourceSwitch` on iPhone: failed once in the final run, passed in the earlier run and in two reruns.
- `testTypingUndoThenRedoRestoresArabicAndEmojiReplacement` (rich-editor prototype) on iPad: passed in the earlier run, then failed, passed, failed.

**Merge-caused failures, fixed**

- Main's `dismissComposerKeyboard` required the software keyboard to rise; on this iPhone simulator it stays minimized, so 4 composer tests failed on `main` itself. The helper now falls back to a settled tap (`8393029`).
- Two notification UI tests used the first navigation-bar button as Back, which in Duo's split layout is the topic-list toggle; the largest-text test tapped outside the iPad form sheet (`e61c93f`).

**Not verified**

- The 3 `MultiWindowNotificationUITests` skip: on this simulator a second window opens full screen, stacked over the first, so the two can't be driven side by side. Tap routing, shared read state and sign-out across windows are covered by the unit tests only. Split View/Stage Manager on a device or configured simulator is still needed.
- Live push delivery, deployed behaviour and real multi-window use on a device.
