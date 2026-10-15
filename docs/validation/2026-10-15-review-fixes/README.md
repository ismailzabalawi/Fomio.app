# Independent review of 6162c57 — findings, resolutions and verification

Review: Codex, 2026-10-15, of commit `6162c578d1ce69ea97301ee00d6a6e448c276a7d` on `claude/fomio-localization-impl-48ecab` (base `3029737`). The report was delivered at `/private/tmp/fomio-localization-review-6162c57.md` (temporary location); its findings are restated here. The reviewer's own run: `FomioTests/LocalizationTests` + `TopicCardTests`, iPhone 17 / iOS 26.1, 24 passed, and the findings were source-based.

Fixes were made in the same worktree and branch; `main` was not touched. No merge, push, publication, deployment or backend edit.

## Findings and resolutions

### 1. Retained app errors did not follow the interface language (P2)

**Finding.** `FeedState.error` stored `error.localizedDescription`, so `RepositoryError.errorDescription` was resolved through `L(...)` when the error was caught. A feed that failed in English kept English error text under Arabic chrome after a language switch.

**Resolution.**
- `DisplayError` (`Fomio/Domain/Models.swift`) holds either a catalog key with arguments, resolved each time it renders, or verbatim text (Discourse validation messages and system errors). `RepositoryError.display` maps cases to keys; `.invalid` (server text) stays verbatim.
- The audit converted every retained error: feed, community directory, theme, discussion and child-branch errors, composer error and rejection, the photo upload status stored in draft JSON (it decodes older plain-string drafts as verbatim), and the profile, drafts, saved, notifications, search, block-form and similar-discussion screens.
- Modal `banner` alerts and 3-second toasts still resolve when raised; they cannot outlive a language change unseen.
- A failed feed no longer refetches by itself when it reappears (a tab return, or the tab rebuild after a direction change). It waits for Try again or pull to refresh, so the retained error is shown rather than replaced by a silent request.

**Tests.**
- `ReviewFixesTests.testRetainedFeedErrorResolvesInTheActiveLanguageWithoutRefetch`: one fixture request; text English → Arabic → English.
- `testServerAndSystemMessagesStayVerbatimAndArgumentsAreKept`
- `testRetainedErrorsInDraftsAndAppStateStaySemantic`: draft round trip, legacy decoding, directory and discussion state.
- UI `ReviewFixesUITests.testRetainedFeedErrorFollowsLanguageWithoutRefetch`: English failure → Me › Language › Arabic → Home shows the same error in Arabic, the topics are absent (no refetch), and explicit retry loads.

### 2. UIKit direction could follow the device instead of the interface (P2)

**Finding.** `Localizer.activate` set `UIView.appearance().semanticContentAttribute` to `.unspecified` for LTR catalogs, which means the system direction (RTL on an Arabic device). It also returned before setting anything when the initial English fallback equalled the stored catalog.

**Resolution.**
- Every activation now sets `.forceLeftToRight` or `.forceRightToLeft` explicitly, including the cold-launch English fallback, before the equality check.
- Only the app's shared localizer drives UIKit; test-local instances never touch it.
- App-owned UIKit composer cards also set the catalog direction on themselves and their subviews (`ComposerAttachmentCard.applyDirection`). The editor text view and the More menu button already read the catalog direction.

**Tests.**
- `ReviewFixesTests.testSharedLocalizerSetsExplicitUIKitDirectionForEveryActivation`
- UI tests run with Arabic as the app's iOS language (`-AppleLanguages (ar) -AppleLocale ar_SA`):
  - `testArabicSystemLanguageColdEnglishFallbackKeepsAppUIKitLeftToRight`: offline first launch, English. Tabs run left to right; the quote card shows Edit before Remove; More menu captured.
  - `testArabicSystemLanguageSwitchArabicToEnglishRestoresAppUIKitDirection`: Arabic shows a mirrored card and menu; switching to English restores left-to-right tabs, card and menu.

**Observed system-owned behaviour, intentionally unchanged.**
> **Superseded 2026-10-15 by the [re-review fixes](../2026-10-15-rereview-fixes/README.md):** the reversed Back chevron is now fixed in the app; the observation below records what `b8eb0b0` showed.
- With Arabic as the iOS language and English as the interface, the system navigation back button is on the left, but its chevron glyph still points right. The same is true of the localized SF Symbol variant for "Edit in Markdown" (`textformat` shows أ).
- These follow the app's iOS language, which UIKit resolves at launch. A window layout-direction trait override was tried, had no visible effect on the glyph, risked a launch crash (reading an absent override throws), and was removed.
- Choosing English in iOS Settings › Fomio › Language aligns them. Captures: `*-2a…`, `*-2b…`, `*-2e…`.

### 3. Failed topic media never recovered (existing P2)

**Finding.** `TopicCard.mediaFailed` was permanent for the view's lifetime, so a replaced URL or an explicit refresh of the same topic stayed text-only.

**Resolution.**
- `MediaFailure` records the failed source and the feed's `refreshGeneration`.
- A different source (replaced URL) loads at once.
- A successful explicit refresh (`FeedState.load(refresh: true)`) advances the generation and retries a failed source once. A failure in that generation hides it again, with no automatic retry loop.
- Only a retry changes the image view's identity, so loaded images are not re-requested on refresh.
- *Correction (re-review):* in `b8eb0b0` this held only until the next refresh. A recovered image was recreated on every later refresh. It is fixed and measured with request counts in the [re-review record](../2026-10-15-rereview-fixes/README.md).
- Load-more and failed refreshes keep the current media state.

**Tests.**
- `ReviewFixesTests.testMediaFailureIsScopedToSourceAndRefreshGeneration`
- `testRefreshGenerationAdvancesOnlyOnSuccessfulExplicitRefresh`
- `testFixtureMediaRecoveryRestoresFileAndReplacesURLOnRefresh`
- UI `testFailedMediaRecoversAfterRefreshAndReplacementInCompactThenCards`: both images fail (text only, authors theo/mara_k correct) → pull to refresh → restored same source and replacement both shown → switch to Cards keeps them → open a topic and Back → a second refresh keeps them.
- UI `testMediaRecoveryInArabicCardsWithAccessibilityText`: Arabic Cards at accessibility3; failure then recovery after refresh.
- Fixture `--media-recovery`: one image file absent until the next explicit refresh (server unreachable, then restored); one missing URL that the refresh replaces.

## Commands, devices and results

Xcode 27.0 (27A266a); simulators iPhone 17 (`73AD51BF-…`) and iPad Pro 11-inch (M5) (`4D6E1977-…`), iOS 26.1, English device language except where `-AppleLanguages (ar)` is stated. Fixture mode and fixture catalogs only.

```sh
xcodegen generate
xcodebuild -project Fomio.xcodeproj -scheme Fomio -destination 'platform=iOS Simulator,name=iPhone 17' test
xcodebuild -project Fomio.xcodeproj -scheme Fomio -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' \
  -only-testing:FomioTests -only-testing:FomioUITests/LocalizationUITests \
  -only-testing:FomioUITests/FeedAppearanceUITests -only-testing:FomioUITests/ReviewFixesUITests test
```

Final source (identical app code for all rows below):

| Run | Device | Result |
| --- | --- | --- |
| Full suite (`test`) | iPhone 17, after a simulator reboot | **115 unit/contract (4 live skipped), 45 UI (1 live skipped), 0 failures**, no compiler warnings |
| `FomioTests` + `LocalizationUITests` + `FeedAppearanceUITests` + `ReviewFixesUITests` | iPad Pro 11-inch (M5) | **115 unit/contract (4 live skipped), 18 UI (7 + 6 + 5), 0 failures** |
| Earlier full suite on the same app source | iPhone 17 | 115 + 45, 0 failures; in a second pass before the reboot, only `FomioUITests.testArabicComposerPreservesMixedTextAcrossModesAndRotation` failed because the simulator never rotated (it stayed portrait; the text was intact). The test failed twice more in isolation, then passed after `simctl shutdown`/`boot`, as did the following full suite. Recorded as simulator orientation state, not an app change |

Test counts by class: 108 → 115 unit tests (`ReviewFixesTests`, 7 new) and 40 → 45 UI tests (`ReviewFixesUITests`, 5 new). Live-network tests stay skipped without opt-in. Result bundles are local scratch artifacts and are not committed.

Screenshots (all inspected), `iphone-*` and `ipad-*`:
- 1a–1c: retained error, then Arabic, then retry.
- 2a–2e: Arabic iOS language — cold English fallback, quote card, English and Arabic More menus, Arabic → English.
- 3a–3f: media failure, then recovery, Cards, Back and refresh, Arabic accessibility3.

## Additional checks requested for the affected areas

| Area | Evidence |
| --- | --- |
| Appearance persistence and switching anchor | `FeedAppearanceUITests` (persist across relaunch, mid-feed and partly hidden anchors both directions) on iPhone and iPad; recovered media kept across the Compact → Cards switch (3c) |
| Navigation return | Back from a topic keeps Cards and recovered media (3d); language switch keeps tab stacks (`LocalizationUITests`) |
| Pages and errors | `FeedAppearanceUITests` failed "More discussions" page and retry; retained Home error and explicit retry (1a–1c) |
| Content direction | English titles left-to-right and the Arabic-titled topic right-to-left in the Arabic UI (`LocalizationUITests` captures; 3e/3f) |
| Author accuracy | Labels asserted to contain "started by theo"/"started by mara_k" and «بدأه» |
| Dynamic Type | Arabic Cards at accessibility3 on iPhone and iPad (3e/3f); `LocalizationUITests` accessibility-text run |
| Narrow and iPad layouts | iPhone 17 (narrow) and iPad Pro 11-inch (regular width) for all review-fix journeys |

During verification, the iPad media tests first failed because a fixed 420-point pull was below the refresh threshold on the taller screen. Manual simulator gestures confirmed that refresh and recovery work, and the test now drags a proportion of the window height. No app change was needed for that.

## Limits

- Fixture data and fixture catalogs only; no live Discourse calls.
- Localized SF Symbol variants follow the iOS language. The back chevron was fixed later; see the re-review record.
- `FomioUITests` (the original journeys) ran on iPhone only, as before.
- Physical-device and VoiceOver checks were not part of this pass.

## Release gates still open (unchanged by these fixes)

- The native catalog endpoint does not exist on the deployed backend; live builds stay English. A separately authorized backend task, deployment and live verification are required.
- A native Arabic speaker has not yet reviewed `Localization/catalogs/ar.json`.
- No physical-device VoiceOver walk-through has been done.
- Terminology policy: the native app keeps discussion/community and does not adopt the forum's Byte/Hub/Teret overrides. This needs product agreement.

The branch remains unmerged.
