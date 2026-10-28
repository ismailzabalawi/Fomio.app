# iPhone Duo native UI/UX validation — 2026-10-25

Run 2026-10-25 (Asia/Amman). Scope: **English/LTR**, existing native SwiftUI client in labelled fixture mode, read-only against design artifact version 5. Validation only: no Fomio source, backend, artifact or toolchain change.

**Result: Duo is not ready.** Core composer continuity passes on a genuine Duo simulator. One navigation defect fails, and several required cases are blocked or not run (see [Remaining gates](#remaining-gates)).

## What was tested

| Item | Value |
| --- | --- |
| Documentation checkout | This worktree, branch `codex/discourse-reporting-ia` at `88e5136` (clean). It does **not** contain the Duo implementation or the Duo guideline/audit documents. |
| Native implementation | Main checkout `/Volumes/Develop/Projects/Fomio Swift`, branch `duo-adaptive-reading` at `8e2a2487c2e6` (“Defer search field focus dismissal on Return for iPad popovers”). Source tree clean; uncommitted changes are documentation only (`docs/README.md`, untracked `docs/design/iphone-duo-ui-ux-guideline.md`, `docs/design/audits/`, branding/App Store assets, Xcode Cloud folder). Built from a `git archive` export of that commit, so neither checkout was written. |
| App build | Fomio 0.8.0 (7), Debug, `iphonesimulator27.1`, launched with `--fixture` (“Sample content” banner visible in every capture). Installed over the existing Fomio on the simulator. Its data container was preserved, including an earlier session’s draft (“Fold continuity draft…”), which was left untouched. |
| Design reference | [Fomio Duo Adaptive Reading](https://claude.ai/artifact/RhY9nhQTFxDTMk5PVT4AYn) (`c80446c4-…`): a private Design canvas, published version id `1792933457-2df2`, read-only. Prototype behavior below comes from the existing [v4](../../design/audits/2026-10-25-duo/version-4-verification.md) and [AX-fallback](../../design/audits/2026-10-25-duo/ax-fallback-fix-verification.md) records in the main checkout. Those links resolve only there; this run did not re-inspect the canvas markup. |
| Apple references | [Duo HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) (change log: new page, 9 Sep 2026), tech talks [111461](https://developer.apple.com/videos/play/tech-talks/111461/), [111462](https://developer.apple.com/videos/play/tech-talks/111462/), [111463](https://developer.apple.com/videos/play/tech-talks/111463/), [111466](https://developer.apple.com/videos/play/tech-talks/111466/), read live on this date. |
| Backend | Not relevant: no Discourse contract was exercised and no write was attempted. `/Volumes/Develop/Projects/Dicourse` is at `d4296c5ecf2`; it was not opened or changed. `docs/discourse-api-reference.md` needs no update. |

## Tooling inventory

| Tool | Observed |
| --- | --- |
| Xcode | `/Applications/Xcode.app/Contents/Developer`, Xcode 27.1 (`27A9275`) |
| SDKs | iOS 27.1, iOS Simulator 27.1 (plus tvOS, visionOS and watchOS 27.0) |
| Simulator runtimes | iOS 26.0, 27.0 and 27.1 |
| Duo device | Device type `iPhone Duo`. Existing simulator `iPhone Duo` / iOS 27.1 (`FD81C641-…`), already booted, reused. Displays: inner 2007×2853 px, outer 1398×2034 px. No simulator was created, cloned, erased or reset. |
| Device Hub | `DeviceHub.app` (Xcode 27.1). Exposes **Closed / Partially Open / Open / Rotate Right**, Enter Resize Mode, Capture Keyboard, Toggle Software Keyboard, and switches for Appearance, Reduce Motion, Increase Contrast, Reduce Transparency, VoiceOver and Text Size. It has no camera-activation control and no named book/tabletop poses. |
| Automation used | Device Hub via macOS Accessibility (`AXPress` on the named controls). Simulator taps, text and screenshots via the Claude simulator tool and `simctl io`. Real pointer drags on the Device Hub canvas via a disposable CGEvent helper; this was needed for Split View, because injected touches did not trigger the multitasking gesture. Read-only LLDB batch expressions for window bounds, traits, safe areas, `verticalBarEdge`, `reservedRegions` and editor state. |
| Also present but unused | Accessibility Inspector, Instruments, XcodeBuildMCP (`npx`). `idb` and `axe` are not installed. |

Not used: physical device, iPhone Mirroring, live Discourse site, the Mac’s camera.

## Evidence labels

- **Apple**: statement read from the live HIG or talk transcripts.
- **Prototype**: what design artifact v5 depicts, per the existing verification records.
- **System probe**: a disposable SwiftUI app built outside the repository with standard containers (`TabView`, `NavigationStack`, `.sheet` + `.presentationPlacement`, toolbars). It establishes **OS component behavior only, not a Fomio pass**. Source is kept as evidence: [`probe/probe-source.swift.txt`](probe/probe-source.swift.txt). It was uninstalled from the simulator afterwards.
- **Fomio**: the native app under test.

Sizes are in points from native inspection (`state/*.log`, `probe/*.json`). Probe JSON frames are in the window’s global coordinates; reserved-region frames are relative to the measuring view. Captures are downscaled to 900 px and establish composition, not point measurements.

## System-probe results (OS behavior, not Fomio)

| # | Device Hub pose / measured geometry | Observed | Matches Apple? | Evidence |
| --- | --- | --- | --- | --- |
| S1 | Closed, portrait. 466×678, compact/regular | Bar trailing; status column (time, Wi‑Fi) at top right under the camera; tab bar at the bottom of the bar. Upside-down portrait is not offered (a further Rotate Right stays portrait). | Yes | `probe/P09*`, `P10*` |
| S2 | Closed, landscape A. 678×466, compact/compact | Bar **trailing (right)**; camera bottom-right; **no time/Wi‑Fi drawn** (status hidden; only an 84×82 camera/island region). | Yes (HIG outer-landscape diagram). Status hiding is new native evidence. | `probe/P08-closed-base-outer.png` |
| S3 | Closed, landscape B. 678×466 | `toolbarVerticalEdge = leading`: bar **on the left**, camera **top-left**, no time/Wi‑Fi. Content inset to x = 100. Bar item order unchanged. | Yes (talk 111461: controls can be on the left in landscape). This confirms the prototype’s *derived* geometry. | `probe/P11-closed-rotR3-base-outer.png` |
| S4 | Open, landscape. 951×669, regular/regular | Bar trailing; status region 84×124 top-right; **inner camera inactive** at (677, 21) 58×37, top of the right half. Division region inactive at x = 455.5, 40 pt wide. | Yes | `probe/P01-open-landscape-base*` |
| S5 | Open, landscape rotated 180° | Bar stays on the right; **inactive camera moves to the bottom-left** (≈215, 610). | Not documented by Apple; observed | `probe/P03*` |
| S6 | Open, portrait. 669×951, regular/regular | `toolbarVerticalEdge = nil`: horizontal bars; safe-area top 82; inactive camera on the right edge about **71 % down** (≈611, 677). | Yes. This confirms the earlier geometric inference. | `probe/P02*`, `P07*` |
| S7 | Sheets, open landscape | automatic = centered 621×473, horizontal bars. `.leading` = x 24, horizontal. `.trailing` = x 306–851, full height, **vertical bar on its trailing edge** (x 884): Cancel y 29, Done y 89, bottom group (Bold, Photo) y 550/602. | Axis rule matches talk 111462 | `probe/P01-*-sheet-*` |
| S8 | **Trailing sheet’s top actions** | Cancel and Done sit **inside the active status region (0–124)**: time and Wi‑Fi draw over them, and Cancel is not visibly distinguishable. Persists after settling. The root window’s bar correctly starts below it (Back at y 129). | No Apple statement; possible OS/simulator issue | `probe/P01-open-landscape-sheet-trailing-settled-inner.png`. Frames come from an LLDB control dump (`state/controls-probe.lldb.txt`) read in-session; the dump output itself was not saved. |
| S9 | Sheets, open portrait | `.leading` and `.trailing` both lay out identically: 621×673 at x 24, horizontal bars. **Explicit placement has no visible effect.** | Consistent with talk 111466 (inner portrait uses horizontal bars) | `probe/P02-*-sheet-*` |
| S10 | Partially Open, landscape (book) | Window stays 951×669; division **active** at x 455.5–495.5. `.leading` sheet shrinks to the left half (x 24–451), horizontal. `.trailing` sheet shrinks to the right half (x 499–850), vertical trailing bar. Both clear the fold. | Yes (sheets avoid the fold) | `probe/P04*`, `P06*` |
| S11 | Partially Open, portrait orientation (horizontal hinge; tabletop geometry) | Division active horizontally at y ≈ 455–495. Both placements are identical (621×673), **spanning the fold**, with horizontal bars. Device Hub does not label this pose “tabletop”. | Talk 111466 says partially folded sheets avoid the fold; **not observed for the horizontal hinge** | `probe/P05*`, `P07*` |
| S12 | Split View, probe on the left. Window 469×669, compact | Bar on the **leading/outer** edge (Back x 29). No occlusion region (the camera is in the other half). A 13.5 pt inactive division slice sits at the right edge. Window is 469, not 475.5 (half of 951). | Yes (controls on the outer edge) | `probe/P14*`, `P15*` |
| S13 | Split View, probe on the right | Bar trailing; inactive camera region inside the window (195, 21); status 84×124 at its top-right. | Yes | `probe/P18*` |
| S14 | Split View indicators | **Two home indicators**, one centred under each half, at the bottom. Still present after 20 s idle. One status cluster, at the far right only. | Talk 111461 mentions one indicator for dragging. The two-indicator count is **new native evidence**. | `probe/P15*`, `P21-split-right-idle-20s-inner.png` |
| S15 | Sheets inside a Split View window | `.leading` and `.trailing` both fill the window (345×521). The bar follows the **window’s outer edge**: left window → leading bar at top-left (Cancel y 29, no status there); right window → trailing bar with Cancel at y 129, **below** the status region. Requested placement is not applied. | No Apple statement; observed | `probe/P16*`, `P17*`, `P19*`, `P20*` |
| S16 | Camera active | `AVCaptureDevice` discovery finds **0 front cameras** (discovery only; no capture or permission prompt). The active inner-camera region cannot be produced. | **Blocked** | probe UI `frontCamera=0` |
| S17 | PiP top-pinned resize / fold | **Not run.** It needs a playing video with PiP; not built in this pass. | — | — |

## Fomio results

Text size Standard (Large) unless stated. Light appearance. Software keyboard docked unless stated. Input labels: **on-screen key** means the simulator software keyboard tapped on screen. **Injected text** means the simulator tool’s HID text input, which is not physical-keyboard or on-device input.

| # | Case and steps | Configuration | Result | Observed | Evidence |
| --- | --- | --- | --- | --- | --- |
| F1 | Launch feed, closed | 466×678, compact/regular, bar trailing | Pass | Tabs in the vertical bar with Notifications badge 2. The custom Search and ••• stay in the content header. | `captures/01*`, `state/01*` |
| F2 | Open → two panes | 951×669, regular | Pass, with notes | List + discussion; the first topic is auto-selected. The list header sits about 100 pt lower than the detail header, and the selected row can scroll out of view. | `captures/02*`, `04*` |
| F3 | Reading anchor, auto-selected detail: open, scroll Bench PSU to #7 under an expanded “1 reply” branch, then Closed | open → closed | **Fail (product decision needed)** | Folding shows the **feed list**, not the discussion. Re-opening restores Bench PSU at #7 with the branch expanded (detail state is retained). | `captures/05*`, `06*`, `03*` |
| F4 | Reading anchor, explicit selection: open, tap “Built a standing desk…”, scroll, then Closed | open → closed | Anchor: Pass | Same discussion; #1’s actions and #2 at the top as before the fold. | `captures/07*`, `08*` |
| F5 | **Navigation after F4** | closed 466×678 | **Fail — defect D1** | No Back, no ••• and no Reply control: the native control dump shows only the four tab buttons, even after scrolling to the top. Opening the same discussion natively in compact shows “Back to topic list” at (399, 179) and •••. The only exit is re-tapping Home, which returns to the list with the row highlighted. | `captures/09*`, `10*`, `11*`, `state/08-explicit-closed-controls.log` |
| F6 | Composer, closed: Reply on #1, injected text `DuoVal 1025 fixture reply alpha`, show the software keyboard, on-screen **q** | 466×678 | Pass | Close in the vertical bar; Post (text) stays in the horizontal header; formatting bar above the keyboard. Editor `0x…558a400`, caret {32,0}. | `captures/12*`, `13*`, `state/13*-editor.log` |
| F7 | Closed → Open with keyboard up; on-screen **w** | 951×669, regular | Pass | Same editor and undo manager, first responder, caret {32,0} kept. Centered sheet with horizontal Close/Post; keyboard stays docked; formatting bar clear, Link added. **w** typed without refocusing. | `captures/14*`, `state/14*` |
| F8 | Open → Partially Open (book); on-screen **e** | 951×669, division active | Pass, with note | Sheet moves into the left half; **system keyboard splits around the fold**; same editor, caret {34,0}. A lavender rectangle appeared to the right of the text line once and was gone after the next transition — needs reproduction. | `captures/15*`, `16*` |
| F9 | Rotate (partial, portrait orientation); ••• → **Undo** | 669×951, horizontal bars | Pass | Same editor and caret; Undo removed the **e** typed before the rotation; canRedo = true. One tap landed during the menu’s render lag and opened **Preview** (read-only); Back returned to the same focused editor. | `captures/17*`, `18*`, `19*` |
| F10 | → Closed with Redo pending; ••• → **Redo** | outer landscape A, 678×466, compact/compact | Pass | Same editor; Redo restored `…alphaqwe`. Close/Post reachable; formatting bar above the keyboard; one line of writing visible. | `captures/20*`, `21*`, `22*` |
| F11 | Short height + **AX‑XL** + docked keyboard | 678×466, `accessibility-extra-large` | Pass, with note | Close/Post reachable; caret line visible (earlier text scrolls under the header); bar compresses to + / ••• / keyboard. ••• menu leads with Undo/Redo, then Format and Turn into. Later items, including **Edit in Markdown**, need the menu to scroll. Very small writing viewport. | `captures/23*`, `24*`, `25*` |
| F12 | Stage fixture photo (••• → Sample photo, bundled `fixture-photo.jpg`) | outer landscape | Pass | 1 attachment, caret after it, same editor. | `captures/26*`, `state/26*-editor.log` |
| F13 | Process termination | — | Draft persistence: Pass | The app was **SIGKILLed at 18:47:24** when I terminated a hung LLDB session attached to it. **Tooling-induced, not an app crash.** On relaunch, Drafts held the exact body plus photo; submission state `editing` (no post). | `captures/30*`, simulator log excerpt in [Environmental limitations](#environmental-limitations) |
| F14 | Resume the recovered draft; injected **B**; Closed → **C** → Open → **D** → Partially Open | 669×951 → 678×466 → 669×951 | Pass | Same editor across all three transitions; 1 attachment throughout; caret 35 → 36 → 37; typed without refocusing. Once, before the fold, the editor reported `first=false sel={0,0}` while the Mac’s focus was on Device Hub; the fold restored focus and caret. Recorded, not attributed. | `captures/32*`, `34*`, `35*`, `state/33*-editor.log` |
| F15 | Close → Keep / Discard / Keep editing dialog | partial fold, portrait orientation | Pass | Dialog placed **below the active fold**. **Keep draft** kept `…alphaqweBCD` plus photo. Discard was never pressed. | `captures/36*` |
| F16 | Search “joinery” → Closed → Open | 669×951 → 678×466 → 669×951 | Pass | Query, caret, Cancel and Clear search kept. Keyboard visible again after Open. The outer-landscape capture is stored upside down by `simctl` (raw framebuffer), not by the app. | `captures/37*`, `38*`, `39*` |
| F17 | Fomio in Split View, left then right | 469×669, compact | Pass | Bar on the outer edge each side; badge visible; search query kept through the two-pane → one-pane resize. | `captures/41*`, `42*` |
| F18 | Inner portrait | 669×951, **regular** width | Observation | One pane only, because Fomio’s 720 pt threshold exceeds 669. HIG suggests showing an extra hierarchy level on the inner display where it makes sense: a product decision. | `captures/31*` |
| F19 | Sidebar ↔ tab parity | — | Not applicable on Duo | The sidebar needs ≥ 1080 pt. The widest Duo window measured is 951 pt, so the sidebar never appears. Badge parity between vertical and horizontal tab bars: Pass (F1, F17, F18). | — |
| F20 | Increase Contrast | open | Observed only | Applied (keyboard key tint changed). One capture, no clipping seen; not an acceptance check. | `captures/39*` |
| F21 | Dark appearance | — | **Not run** | `simctl ui appearance dark` did not take effect within the capture window (trait still light). | `state/39*` |
| F22 | Reading anchor in partial fold, multitasking resize with composer, community chooser, sign-in, report and photo-picker sheets | — | **Not run** | — | — |

No Post, upload retry or authorization action was triggered. The fixture “upload” of the sample photo is local to the fixture service.

## Native tests

| Run | Result |
| --- | --- |
| `FomioTests` (unit bundle), iPhone 17 / iOS 27.0, SDK 27.1, built with `CODE_SIGNING_ALLOWED=NO` | **181 executed: 176 passed, 4 skipped, 1 failed.** The four live-site tests are gated by `FOMIO_LIVE_*` and were skipped by design. The failure is `ContractTests.testKeychainRoundTripAndRemoval` (“Could not remove saved authorization.”). |
| Same keychain test rebuilt with the project’s own signing settings | **1/1 passed.** The failure came from my unsigned build override, not the app. No project signing setting was changed. |
| UI tests | Not run. They would take over the Duo during the manual matrix; earlier Duo UI-test results stay in their own records. |

## Accessibility

| Check | Status | Note |
| --- | --- | --- |
| Accessibility tree | Inspected (native view hierarchy via LLDB) | Labels found: “Back to topic list”, tab names, Notifications badge. This is **not** VoiceOver navigation. |
| VoiceOver navigation and focus order | **Not run** | Procedure below |
| Full Keyboard Access | **Not run** | No FKA control in Device Hub; needs Settings → Accessibility on the simulator, or a device |
| Reduce Motion, Reduce Transparency | **Not run** | Device Hub switches exist |
| Increase Contrast | Observed once (F20) | — |
| Accessibility text sizes | AX‑XL composer case run (F11) | Reading/list layouts at AX not re-run in this pass |

Reproducible procedure for the pending checks: on the Duo simulator, turn on VoiceOver in Device Hub (Settings panel) and open discussion → Reply. Swipe through Close, Post, editor and formatting bar. Fold/unfold and confirm VoiceOver focus stays on the editor and announces the same element. Repeat with Reduce Motion and Reduce Transparency on, and with Full Keyboard Access (Tab / Shift‑Tab through the composer). Record each result here. Physical-keyboard and on-device checks need hardware.

## Findings

### Native implementation defects (not fixed here)

1. **D1 — collapse from two panes loses navigation chrome (High).** After explicitly selecting a discussion in the open two-pane layout and folding, the compact discussion has no Back, no ••• and no Reply bar (F5).
   - Expected: the same chrome as a natively pushed discussion.
   - Likely area: the `ReadingLayout` / `NavigationSplitView` collapse path, where the detail is shown without a navigation stack that has the list as its root.
   - Next action: reproduce in a focused UI test (select in regular width → force compact → assert “Back to topic list” exists), then fix in a separate implementation task.
2. **D2 — auto-selected detail is dropped on collapse (Medium; needs a product decision).** If the reader scrolled the auto-selected discussion (F3), folding returns to the list. The guideline says to keep the selected discussion visible. Decide whether reading an auto-selected detail counts as a selection; if so, treat scroll or interaction as selecting it.
3. **D3 — draft banner shows raw upload Markdown (Low, not Duo-specific).** The banner previews `![Photo](upload://fixture-…)` (F13).
   - Next action: summarize attachments in the banner text.
4. **Observations for design review (not defects yet):**
   - Duplicate photo affordances in the composer: an in-body photo block with Edit/Remove, plus a separate “Photo attached / Remove photo” row.
   - The list/detail header vertical offset and the auto-selected row scrolling out of view (F2).
   - The one-time lavender rectangle (F8).
   - Inner portrait showing one pane at regular width (F18).
   - Composer overflow needing to scroll at AX‑XL in short height (F11).
   - Fomio uses none of the 27.1 Duo APIs (`presentationPlacement`, `toolbarVerticalBehavior`, `toolbarVerticalCompressionBehavior`, `ToolbarOverflowMenu`, `visibilityPriority`, `reservedRegions`); it relies on system defaults. Its feed ••• is a custom menu, while the HIG reserves the ellipsis for the system overflow — review against the guideline.

### Mockup corrections, confirmed or new

| Prototype claim (v5) | Native evidence | Action |
| --- | --- | --- |
| Opposite outer landscape: camera top-left, controls left (*derived*) | Confirmed (S3) | Relabel from “derived” to “observed in the Duo simulator, iOS 27.1” |
| Outer landscape status | **Hidden in both directions** (S2, S3) | Mark the status as hidden in outer landscape |
| Inner camera in portrait about 70 % down the right edge (*inference*) | Confirmed, about 71 % (S6) | Relabel as observed |
| Inner camera after a 180° inner-landscape rotation | Moves to the bottom-left while bars stay right (S5) | Add if the prototype models that rotation |
| Split View gesture indicators (hidden by default; optional “unverified schematic” ×2) | **Two indicators**, centred under each half, persisting at 20 s idle (S14) | May show two indicators, labelled as observed; still verify on hardware |
| Explicit right sheet with vertical actions | Vertical bar on the sheet’s trailing edge, full height; top actions **overlap the status region** (S7, S8) | Draw actions on the trailing edge. Note the overlap as an OS observation, not a design target. |
| Explicit placement not modelled in Split View or inner portrait | Ignored natively in both (S9, S15). The bar follows the window’s outer edge in Split View. | State that explicit placement has no effect there |
| Partial-fold sheets avoid the fold | True for the vertical hinge (S10); **not** for the horizontal hinge (S11) | Make the tabletop annotation conditional |
| AX full-width fallback for the right sheet | Not tested natively (no AX probe sheet run). Remains a **prototype decision**, not a native rule. | Keep the label |
| PiP dimensions | Not run (S17) | Keep as illustrative |

### Environmental limitations

- **The Mac’s screen locked twice** during the run (`CGSSessionScreenIsLocked`). While locked, Device Hub exposes no window to Accessibility and pose controls cannot be driven. The session’s keep-awake prevents system sleep only, so a time-limited `caffeinate -d` (display) was started for the remainder.
- **SIGKILL of Fomio** (pid 28657) at 18:47:24 followed my termination of an attached, hung LLDB. Simulator log: `termination reported by launchd (2, 9, 9)` … `Process exited … SIGKILL(9)`. Not an app crash.
- Simulator taps sometimes register after a render lag; one tap opened Preview instead of a menu item (F9). Injected text typed before a field had focus was dropped (F16, first attempt).
- `simctl ui appearance dark` did not apply within the capture window (F21).
- No simulated front camera (S16). There is no Device Hub control to activate the camera region.
- Split View required real pointer drags on the Device Hub canvas; injected simulator touches from the home indicator did nothing (`probe/P13*`).
- Floating keyboard: no control in Device Hub, and not available on this device class through the tooling. Not run.
- Simulator software keyboard ≠ physical-device input; LLDB inspection ≠ VoiceOver.

## Remaining gates

Duo is **not** declared ready. Required before acceptance:

1. Fix and re-verify **D1** (and decide **D2**) with a regression test on the Duo simulator.
2. Camera-active reserved region: needs a camera-capable target (physical device), or Apple tooling that can simulate it.
3. PiP top-pinned resize and partial-fold expansion, with Fomio reading and composing.
4. VoiceOver navigation and focus continuity, Full Keyboard Access, Reduce Motion, Reduce Transparency and dark appearance through fold, rotate and Split View.
5. Secondary sheets (community chooser, sign-in, report, block, photo picker) in short and narrow windows and both Split View sides, plus the composer inside a Split View window.
6. Reading anchor and composer through partial fold with the horizontal hinge, and continuous Resize-mode sweeps in both directions.
7. Physical iPhone Duo: input (hardware keyboard, touch), camera and indicator geometry.
8. Prototype relabels listed in the mockup-corrections table (design-side change; outside this validation).

## Evidence index

- `captures/NN-*-{outer|inner}.png`: Fomio screenshots of the active display, numbered as above. `27-photo-unfold-attempt-failed-locked-*` was captured when an unfold click failed because the Mac was locked; it is not an open-pose result.
- `state/NN-*.log`: window bounds, size classes, content size, style, safe area, `verticalBarEdge` (0 none, 1 leading, 2 trailing) and reserved regions. `state/NN-*-editor.log`: editor identity, first responder, selection, undo manager and attachment count. `state/08-explicit-closed-controls.log`: native control dump for D1.
- `state/*-probe.lldb.txt`: the read-only LLDB expressions used.
- `probe/PNN-*.png|json`: system probe captures and in-app measurements. For `--nolaunch` captures the JSON keeps earlier keys; read the key named in the case.
- `probe/probe-source.swift.txt`: probe source (disposable; not part of the Fomio target).

Simulator settings found at the start (light appearance, extra-small text, Increase Contrast off) were restored at the end.
