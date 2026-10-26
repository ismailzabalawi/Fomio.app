# iPhone Duo pose validation — 2026-10-26

Branch `claude/duo-system-bar`, iPhone Duo simulator / iOS 27.1 (existing device reused), Xcode 27.1, fixture content (`--fixture`, "Sample content" visible). Poses were set with Device Hub's own controls, pressed through macOS Accessibility (`AXPress` on the buttons whose help text is Closed, Partially Open, Open and Rotate Right). Screenshots come from the simulator tool. Design reference: the [Fomio Adaptive Reading — SwiftUI Duo](https://claude.ai/artifact/LkZrmM5qkXpovx8QB29C5D) canvas, version `1793000980-747e`, "Native mapping, outside the app" on the comparison board.

## Results

| Pose | Measured | Observed | Verdict | Evidence |
| --- | --- | --- | --- | --- |
| Open, landscape | Reading root 867 pt wide after the bar | Two panes. The vertical bar shows the list toggle, a prominent Reply, Save and Share, then the four tabs with the Notifications badge. The list's Create/Search/More stay with the list column. | Pass | `01-open-landscape-home.png` |
| Partially Open (book) | Division `(455.5, −19, 40, 669)` in reading-root points, reported by `reservedRegions(kind: .division)` | **Before:** the discussion column ran across the hinge, with text inside the band. **After:** the list fills the 455 pt leading region and the discussion starts after the band. Returning to Open restores the normal split with the same selection and draft. | Fixed | `02-partial-before-fix.png`, `03-partial-regions.png` |
| Partially Open, AX Large text | Same division; regions too narrow for two panes | One pane, kept inside the larger (leading) region. Band and trailing region are empty. The list's actions sit at the top of the region; tabs stay in the bar. | Pass | `10-partial-ax-one-region.png` |
| Open + Rotate Right (inner portrait) | 669 × 951 | Horizontal bars: Create/Search/More (feed) or Back, Reply, Save, Share, More (discussion) on top, destinations along the bottom. One pane, because 669 is below 720 (300 + 420), the same rule the design uses. | Pass | `04-inner-portrait-home.png`, `05-inner-portrait-discussion.png` |
| Closed, landscape (short height) | 678 × 466 | **Before priorities:** only Back and More; Reply was in More. **After:** the bar has room for two items. Back stays direct, Reply is first inside More, then Save and Share. That follows the design's order (Back, then Reply). The design's board assumed bar buttons shrink to fit a third item, which the native bar does not do. | Pass with note | `06-closed-landscape-before-priority.png`, `07-closed-landscape-short.png` |
| Closed, opposite landscape | 678 × 466 | Bar and camera move to the left (outer) edge; content clears them. | Pass | `08-closed-opposite-landscape-left-bar.png` |
| Closed, portrait | 466 × 678 | Back, prominent Reply, Save, More (Share and Create); badge on Notifications. | Pass | `09-closed-portrait-discussion.png` |
| Split View, left and right | — | **Not run.** Entering Split View needs a real pointer drag on the Device Hub canvas, which was not attempted. 2026-10-25's F17 passed (bar on the outer edge each side, badge visible) on the earlier build. | Not run on this build | — |

## Implementation established here

- On iOS 27.1, `UIView.reservedRegions(kind: .division)` reports the partial-fold hinge while the window keeps its size. A probe view's `layoutSubviews` is called on each fold change, which is enough to track it (`DisplayDivisionReader`). A Split View's inactive division slice is ignored because only active regions are read.
- Within a division each pane is a region. Two panes need the list's 300 pt × text scale on the leading side and a phone reading width, 320 pt × text scale, on the trailing side; otherwise one pane keeps to the larger region. Safe-area padding did not move the collapsed split's centred reading column, so one-pane confinement pads the frame itself.
- iOS overflows toolbar items by `visibilityPriority` (iOS 27), not by declaration order alone. Reply, Back/list toggle and feed Create are high; Save, Share and feed options are low. Without explicit priorities, Reply and Back went into More in the short bar.

## Limits

- Taps from the simulator tool did not reach the app on this Duo. Pose checks therefore used launch presets (`--preset discussion`) rather than in-app navigation, and composer/keyboard behaviour in each pose was not rerun here. Those are covered by the 2026-10-25 composer records and the UI suite.
- Live data, VoiceOver, physical hardware and Split View remain unverified for this build.
