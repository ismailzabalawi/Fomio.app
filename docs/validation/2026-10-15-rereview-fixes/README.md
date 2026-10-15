# Independent re-review of b8eb0b0: findings, resolutions and verification

The re-review (Codex, 2026-10-15) covered commit `b8eb0b04e29178f7b32f2e9f7259694fd34d79a2` against `6162c57`, on branch `claude/fomio-localization-impl-48ecab`. The report was delivered at `/private/tmp/fomio-localization-rereview-b8eb0b0.md`, a temporary location; its two open findings are restated below. The reviewer independently ran `ReviewFixesTests` and `ReviewFixesUITests` on iPhone 17 / iOS 26.1: 12 passed. It noted that those tests did not assert either gap.

It confirmed that the earlier findings (retained errors, initial UIKit direction, permanent media failure) were resolved, apart from the two items below.

Work stayed in the same worktree and branch. `main` (`3029737`) was untouched; there was no merge, push, publication, deployment or backend edit.

## 1. A recovered image was recreated on every later refresh (P2)

**Finding.** In `b8eb0b0`, `TopicCard` used `url#retry-<refreshGeneration>` as the image view identity whenever the remembered failure matched the source, and nothing transitioned on success. After failure → retry success (`#retry-1`), every further refresh produced `#retry-2`, `#retry-3` … and recreated the loaded `AsyncImage`.

**Resolution.** `MediaLoadState` (`Fomio/Features/TopicCard.swift`) replaces `MediaFailure`:
- `fail(source, generation)` hides that source; there is no automatic retry, so no loop.
- `refreshed(to:current:)` runs from `.onChange(of: refreshGeneration)`. It acts only when the current source is presently failed and the generation is newer: it clears the failure and advances `attempt` once.
- `identity(source)` is `url` before any retry and `url#attempt-N` after the N-th deliberate retry. Success changes nothing, so the identity stays put on later refreshes.
- A different source (a replaced URL) has its own base identity and loads immediately.

**Loader evidence.**
- Fixture images for `--media-recovery` are now served by `FixtureMediaURLProtocol` (`Fomio/Data/FixtureMediaURLProtocol.swift`, Debug fixture mode only). It counts every image request per file and never caches. The counts are exposed in the hidden `fixture-media-requests` element.
- `ReviewFixesUITests.testFailedMediaRecoversAfterRefreshAndReplacementInCompactThenCards` asserts these counts:

| Step | `restored.jpg` | `missing-original.jpg` | `replacement.jpg` |
| --- | --- | --- | --- |
| Launch (both fail); unchanged 2 s later, so no automatic retry loop | 1 | 1 | — |
| Pull to refresh: deliberate retry of the failed source, replacement loaded once, old URL not requested | 2 | 1 | 1 |
| Second refresh: both images kept, nothing requested | 2 | 1 | 1 |
| Switch to Cards (a different media view; at most one load each for the new layout) | ≤3 | 1 | ≤2 |
| Open a topic, Back, refresh again | unchanged | unchanged | unchanged |

- Unit: `ReviewFixesTests.testMediaLoadStateRetriesOnlyDeliberatelyAndKeepsRecoveredIdentity` covers no retry without a new refresh; retry → `#attempt-1`; later refreshes keep it; a failed retry hides it until the next refresh (`#attempt-2`); a replacement loads at its own identity; a refresh never reloads a source that hasn't failed.
- Old-logic check: the identity rule from `b8eb0b0` (identity follows the current refresh generation once a source had been retried) was put back temporarily, and this UI test was run on iPhone 17. It **failed** at the second-refresh assertion because the counts showed `restored.jpg: 3`, a reload. The file was then restored byte for byte, and every final run below used the restored source.

## 2. Back chevron reversed when the iOS and interface directions differ (P2)

**Finding.** With Arabic as the iOS language and English as the interface, the native Back button sat on the left but its chevron pointed right (`ipad-2e…jpg` in the [previous record](../2026-10-15-review-fixes/README.md)).

**Investigation (iPad Pro 11-inch, iOS 26.1).**
- A distinctive temporary image (`star.fill`) confirmed that iOS 26's glass back button honors `UINavigationBar.backIndicatorImage`.
- Supplying `chevron.left` on Arabic iOS with an English interface still showed a right chevron. Supplying `chevron.right` showed a left chevron. So UIKit mirrors the indicator when the app's system direction is RTL.
- On English iOS with an Arabic interface, `chevron.right` stayed a right chevron (no mirroring).
- The window trait override tried in the previous round had no effect and was not reintroduced.

**Resolution.**
- `Localizer.backIndicatorSymbol(interface:systemRightToLeft:)` returns nil when the interface and system directions match, which keeps the system's own chevron untouched.
- When they differ it returns `chevron.right`; UIKit's mirroring then gives the interface's direction in both mismatch cases.
- `applyBackIndicator` sets it on the `UINavigationBar` appearance on every activation, including the cold launch. Bars created afterwards pick it up, and the tab container already rebuilds on a direction change.
- The system direction comes from the app's preferred bundle localization, which is what UIKit uses.
- The native back button, its title, accessibility, the interactive pop gesture, the paths and the return anchors are unchanged.

**Evidence.** `NavigationDirectionUITests`, new, on iPhone and iPad:
- For each configuration, `verifyBack` opens a discussion and then checks:
  - chevron orientation, measured from the dark pixels of the Back button in a screenshot (a left chevron's middle rows sit left of its arms);
  - Back on the leading side;
  - Back's accessibility label names the previous screen ("Home" / «الصفحة الرئيسية»).
- It then taps Back and checks the topic returns to the same position (±4 pt).
- It reopens the discussion and pops with an edge swipe from the interface's leading edge, checking the same position again.
- `testArabicSystemEnglishInterfaceColdLaunchAndSwitching`: Arabic iOS + English on a cold offline launch (mismatch); Arabic iOS + Arabic (matched); switching Arabic → English in-session (mismatch).
- `testEnglishSystemArabicInterfaceCachedColdLaunchAndSwitching`: English iOS + Arabic on a cold launch from the cached catalog with the fixture offline (mismatch); switching to English (matched) and back to Arabic (mismatch).
- `ReviewFixesTests.testBackIndicatorOverridesOnlyMismatchedDirections` covers the rule.

## Commands, devices and results

Xcode 27.0 (27A266a), iOS 26.1 simulators: iPhone 17 (`73AD51BF-C8A8-42F9-AF78-69E6574A4C5C`) and iPad Pro 11-inch (M5) (`4D6E1977-E6DA-418C-9D4D-7EA81187AEC8`). Fixture mode only.

```sh
xcodegen generate
xcodebuild -project Fomio.xcodeproj -scheme Fomio -destination 'platform=iOS Simulator,id=73AD51BF-C8A8-42F9-AF78-69E6574A4C5C' test
xcodebuild -project Fomio.xcodeproj -scheme Fomio -destination 'platform=iOS Simulator,id=4D6E1977-E6DA-418C-9D4D-7EA81187AEC8' \
  -only-testing:FomioTests -only-testing:FomioUITests/LocalizationUITests -only-testing:FomioUITests/FeedAppearanceUITests \
  -only-testing:FomioUITests/ReviewFixesUITests -only-testing:FomioUITests/NavigationDirectionUITests test
```

All rows used the final source.

| Run | Device | Result |
| --- | --- | --- |
| Full suite (`test`), after a simulator reboot | iPhone 17 | **116 unit/contract (4 live skipped), 47 UI (1 live skipped), 0 failures.** `NavigationDirectionUITests` 2/2, `ReviewFixesUITests` 5/5, `LocalizationUITests` 7/7, `FeedAppearanceUITests` 6/6, `FomioUITests` 27 (1 live skipped). No compiler warnings; the only log "warnings" are App Intents metadata-extraction notes. |
| `FomioTests` + `LocalizationUITests` + `FeedAppearanceUITests` + `ReviewFixesUITests` + `NavigationDirectionUITests` | iPad Pro 11-inch (M5) | **116 unit/contract (4 live skipped), 20 UI (7 + 6 + 5 + 2), 0 failures** |
| Earlier full iPhone pass, same source, without a reboot | iPhone 17 | 116 + 46/47 UI. Only `testArabicComposerPreservesMixedTextAcrossModesAndRotation` failed: the simulator never rotated, the same symptom recorded for `b8eb0b0`. It passed after `simctl shutdown`/`boot` in the full run above. This round changed no rotation code. Treat it as simulator orientation state seen after long sessions; it is not reproduced on a fresh boot. |

Test counts: 115 → 116 unit (`ReviewFixesTests` now 8: the identity test was replaced, the back-indicator rule test added) and 45 → 47 UI (`NavigationDirectionUITests`, 2 new; the media test was extended with request counts).

Screenshots (all inspected), as `iphone-*` and `ipad-*`:
- Media: `3a` (both failed), `3b` (recovered after refresh), `3b2` (second refresh, no reload), `3c` (Cards), `3d` (Back + refresh).
- Navigation: for each configuration, `…-back-control` (chevron and position) and `…-after-edge-swipe-back` (returned to the same feed position):
  - Arabic iOS + English (cold)
  - Arabic iOS + Arabic
  - Arabic iOS after Arabic → English
  - English iOS + Arabic (cached cold launch)
  - English iOS + English
  - English iOS after English → Arabic

Result bundles and logs are local scratch artifacts (`h-iphone`, `g-ipad`, `old`), not committed. Earlier rounds' result bundles were deleted to free space on the nearly full system volume; their counts are recorded in the earlier validation records, and the logs were kept.

## Limits

- Fixture data and catalogs only. Request counts come from the fixture media server; they show how often the app's image loader asked for each image, not real-network or CDN behavior.
- UIKit's mirroring of the back indicator was observed on iOS 26.1 simulators. A future iOS that changes this would surface in `NavigationDirectionUITests`.
- Localized SF Symbol variants (for example the typography symbol) and Apple-owned strings still follow the iOS language.
- No physical-device or VoiceOver pass.

## Release gates still open (unchanged)

- The backend catalog endpoint is not deployed, and there is no live verification.
- A native Arabic speaker has not reviewed the translations.
- No physical-device VoiceOver walk-through has been done.
- The terminology policy (discussion/community vs Byte/Hub/Teret) still needs product agreement.

The branch remains unmerged.
