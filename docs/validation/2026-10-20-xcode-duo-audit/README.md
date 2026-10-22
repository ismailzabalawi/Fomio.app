# Independent Xcode Duo audit and width retry — 2026-10-20

**Audit: no blocking finding in the scoped Xcode sign-in/window change. Full compact → regular → compact history acceptance remains open.** The Mac was unlocked; the previous locked-desktop explanation does not describe these retries.

## Scope and evidence

Read Xcode's completed “get my app ready for iPhone Duo.” conversation in the Fomio project, then inspected the source and its recorded result bundles. The working tree includes unrelated safety, release and rich-editor prototype work; this review does not attribute that entire diff to Xcode's Duo task. No backend protocol or deployment claim was changed.

The reviewed change passes the hosting sign-in window from `SignInView` through `AppState.signIn(anchor:)` into `AuthenticationService.signIn(anchor:)`. `PresentingWindowReader` observes its own UIKit hierarchy instead of looking through global connected scenes. All production callers were updated. A missing window fails before a web session starts; the existing session guard and deferred anchor/session cleanup remain. The native menu-order fix and prior keyboard-clearance implementation are preserved.

Against Apple's [Duo preparation checklist](https://developer.apple.com/iphone-duo/prepare/), the current production source has no main-screen sizing, idiom-based layout or orientation-based layout branching. The app uses the SwiftUI scene lifecycle. Its generated simulator app Info.plist independently confirms SDK 27.1, minimum iOS 26, both device families, generated launch screen, all four iPad orientations, scene support and no `UIRequiresFullScreen`. Fixed dimensions also include bounded reading columns and media layouts; they are not all glyph/touch-target sizes, and are not by themselves display-size assumptions. Topic media fill/focal cropping, vertical bars and the broader screen matrix still require the manual acceptance recorded in the readiness document.

## Window-anchor validation

Independently read Xcode's existing machine-local result summaries:

- `/tmp/fomio-duo-unit.xcresult`: 125 passed, 0 failed/skipped, original Duo `5325EFBF-C37B-47D8-AE20-41CCB4945844`, iOS 27.1.
- `/tmp/fomio-duo-signin.xcresult`: 7 passed, 0 failed/skipped, same Duo/runtime. Fixture sign-in and existing authorization checks do not exercise a live web session or the new anchor's identity.

Added two focused tests in `ContractTests` to close part of that coverage gap:

1. `testAuthenticationWithoutPresentingWindowFailsBeforeStartingSession` checks the nil-window failure without opening a browser or touching the server.
2. `testPresentingWindowReaderTracksItsOwnWindowAndDetachment` attaches the reader to two scene-associated windows that never become key, checks each reported identity, then checks nil on removal.

Both pass on the second Duo `FD81C641-B4C2-4E69-9459-867DE508F033` / iOS 27.1: **2 passed, 0 failed/skipped**, bundle `test_sim_2026-10-20T04-26-34-359Z_pid63235_9055bedd.xcresult`. The preceding attempt disconnected before test execution (`test_sim_2026-10-20T04-24-44-580Z_pid63235_cde9e79a.xcresult`); it is not passing evidence. These results do not establish live `ASWebAuthenticationSession` continuity while folding, resizing or backgrounding.

## Width journey: still failed

Bundles below live under `~/Library/Developer/XcodeBuildMCP/workspaces/Fomio-Swift-a437303753c0/result-bundles/`. Both runs use the retained native fixed-order menu fix and the opt-in `testKeyboardAndHistoryAcrossManualWidths`. Neither completed Redo/Undo at regular width or the compact return.

| Bundle | Observed result |
| --- | --- |
| `test_sim_2026-10-20T04-19-28-084Z_pid63235_581c063c.xcresult` | Original Duo: initial Undo succeeds, expected draft and keyboard remain queryable at regular width, then More reachability wait fails. Window `{{-331,273},{1000,678}}`, More `{{-88.5,331},{47.7,44.3}}`, keyboard `{{0,53},{669,253}}`, `hittable=0`. Geometry attachment is a black display. **1 failed.** |
| `test_sim_2026-10-20T04-28-26-424Z_pid63235_3529ae06.xcresult` | Fresh Duo: initial Undo succeeds and 1000×678 is reached, then the same reachability gate fails. Application 1000×678, window 333.3×226, More `{{236.6,200.7},{15.9,14.8}}`, keyboard `{{267,722},{466,245}}`, `hittable=0`. **1 failed.** |

The fresh simulator reproduces the display-scale/coordinate mismatch; its window and More frames are divided by three while keyboard coordinates refer elsewhere. This blocks using the automation as user-input acceptance. It does not prove that every regular-width app layout/history behavior is correct. The test's reachability and keyboard-clearance requirements were retained.

Device Hub coordinate clicks initially failed with `noWindowsAvailable`; its compact window restored a coordinate click, while management/resize control routing remained unstable. Native keyboard traversal between the width and height fields finally committed 1000×678 on the fresh simulator. Host load rose above 400. The old Duo was shut down after its completed run to reduce load; no simulator data was erased and unrelated simulators were left alone.

A subsequent native-pose fallback could not be evaluated: installation failed with `IXErrorDomain`/`IXPlaceholder`, and a launch reported successful by the tool actually logged `NSPOSIXErrorDomain code 3`, “did not return a process handle nor launch error.” No Fomio PID was found. The accessibility bridge then threw `NSInternalInconsistencyException: Invalid parameter not satisfying: self.supportsAutomationMode`. These failures are recorded rather than counted as an app run or history success.

The native-display fallback was stopped when booting the original Duo returned `NSPOSIXErrorDomain code 2`: its `.../Devices/5325EFBF-C37B-47D8-AE20-41CCB4945844/data` directory no longer exists. A filesystem check confirmed the missing directory. The second Duo's data directory still exists. The agent issued shutdown commands only, not erase/delete commands; the cause of the missing data was not established. Both Duo simulators used for this investigation are now shut down to avoid additional load. A stable simulator installation is required before further acceptance retries.

Apple's current [Duo HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) was available through the official search result after the direct page returned a JavaScript shell. It calls for continuity across displays, adaptable safe-area-aware layouts and consistent controls. A native inner-display portrait route was considered as an alternative to the failing resizable display, but was not executed successfully and supplies no additional acceptance evidence.

## Remaining gates

- Complete actual Redo/Undo and new typing/Undo at regular width, then repeat after compact return with the same open reply and visible unobstructed keyboard, using a working native input route. Do not substitute `canUndo`/`canRedo` flags or coordinate corrections in production code for those actions.
- Verify the live authorization sheet on its caller's scene through fold/resize and authorization return. Fixture and offscreen window tests cover only the local plumbing.
- Continue the existing Duo matrix for vertical bars, media crops, secondary sheets, accessibility/RTL, lifecycle, Markdown trait crossing and upload/submission continuity.

No production change was necessary from this audit. Only the two focused window-anchor tests and this evidence/documentation follow-up were added.
