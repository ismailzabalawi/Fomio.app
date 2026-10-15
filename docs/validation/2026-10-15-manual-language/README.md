# Manual interface language choice and the catalog plugin: verification

Date 2026-10-15. App branch `claude/fomio-localization-impl-48ecab`, source commit `2dda70b` (tests ran on that exact tree; the record and docs were committed afterwards). `main` untouched; nothing merged, pushed, deployed or published. Xcode 27.0, iOS 26.1 simulators: iPhone 17 (`73AD51BF…`) and iPad Pro 11-inch (M5) (`4D6E1977…`).

Fixture catalogs (`FixtureLocalizationTransport`) stand in for the endpoint. They prove app behavior, **not** the deployed backend.

## Product rules verified

- Fomio starts in English; English is the fallback. The device/iOS language, the site's `default_locale`, a member's locale and a catalog discovered in the background never switch it.
- Me › Language lists English plus the site's languages the app can validate (complete, plural rules, direction). The fixture index also contains French (complete, no app plural rules) and German (incomplete); neither is listed.
- A selection is saved only after its catalog validates; relaunch and offline use the last good cache.
- Failed, incomplete or unsupported selections change nothing.
- Removed language: no automatic switch, no request for it, choice kept. With a valid cache the copy stays and the notice says so; with a missing, corrupt or incompatible cache English is shown and the notice says English is shown. Opening Me › Language revalidates the list even when the cached index is younger than 24 hours.
- `CFBundleLocalizations` = `[en]`: iOS offers no per-app language competing with the in-app choice.

## Results (final source `2dda70b`)

| Run | Scope | Result |
| --- | --- | --- |
| iPhone 17, full scheme | 120 unit/contract + 52 UI | **0 failures**; skipped: 4 live unit checks (need `FOMIO_LIVE_READ_TESTS`/`FOMIO_LIVE_WRITE_TESTS`) and 1 live UI test |
| iPad Pro 11, selected | 120 unit/contract + `LocalizationUITests`, `FeedAppearanceUITests`, `ReviewFixesUITests`, `NavigationDirectionUITests` | **0 failures**: 120 unit (4 live skipped) + 25 UI, none skipped |
| Backend plugin | `LOAD_PLUGINS=1 bin/rspec plugins/discourse-fomio-app-locales/spec` at backend `6eca1a33a4a` | 46 examples, 0 failures; RuboCop and syntax_tree clean |
| Live, read-only | `GET https://meta.fomio.app/fomio/app-locales/1/{index,ar,en}.json`, 2026-10-15T17:46:12Z | 404 for all three; generator 7b4f0970 (plugin not deployed) |

### Earlier runs in this round (kept, not hidden)

1. iPhone full run on the pre-fix tree: 3 UI failures, all from outdated assumptions:
   - `FeedAppearanceUITests.testDarkAccessibilityTextAndRightToLeftCaptures` and `FomioUITests.testArabicComposerPreservesMixedTextAcrossModesAndRotation` expected Arabic from the iOS language alone; they now choose Arabic explicitly (`--language ar`) on an Arabic device.
   - `LocalizationUITests.testRemovedLanguageKeepsCachedCopyAndSaysSo`: the first launch cached a fresh index, so the removal was not discovered within 24 hours. Fixed in the product (opening Me › Language revalidates) with a unit regression; the UI assertions are unchanged.
2. Targeted iPhone run (unit + the 3 cases): 120 unit and 2 cases passed; the composer rotation case failed at the window-rotation wait (the known simulator orientation flake). After a simulator reboot it passed on its own run, then again in the final full run.

## New tests

Unit (`FomioTests/LocalizationTests.swift`): `testFreshInstallStaysEnglishAfterCatalogDiscoveryRegardlessOfDeviceSiteOrMemberLocale`, `testExplicitSelectionPersistsOnlyValidatedChoicesAcrossRelaunchAndOffline`, `testFailedIncompleteAndUnsupportedSelectionsChangeNothing`, `testColdOfflineLaunchShowsEnglishAndSelectionFailsWithoutChangingChoice`, `testRemovedLanguageKeepsLastGoodCacheWithoutAutoSwitching`, `testOpeningLanguageRevalidatesAFreshCachedIndexAndFindsARemovedLanguage`, `testRemovedLanguageWithMissingCorruptOrIncompatibleCacheShowsEnglishAndKeepsTheChoice`, `testAutonymNamesALanguageTheSiteNoLongerLists`.

UI (`FomioUITests/LocalizationUITests.swift`): `testArabicDeviceFreshInstallStaysEnglishAfterCatalogDiscovery`, `testExplicitSelectionPersistsAcrossRelaunchAndOffline`, `testFailedSelectionKeepsEnglishAndOffersRetry`, `testRemovedLanguageKeepsCachedCopyAndSaysSo`, `testRemovedLanguageWithoutCacheShowsEnglishAndSaysSo`. Navigation (`NavigationDirectionUITests`), media recovery and render-time errors (`ReviewFixesUITests`) were rerun unchanged except that the Arabic-device fallback no longer passes the removed `--language system`.

## Screenshots (iPhone 17, final run; inspected)

| File | Shows |
| --- | --- |
| [1](iphone-1-arabic-ios-fresh-install-english-after-discovery.jpg) | Arabic iOS, site default `ar`: English checked, Arabic offered, no device row, no French/German |
| [2](iphone-2-explicit-arabic-after-relaunch-offline.jpg) | Arabic chosen in Me › Language, relaunched offline: cached Arabic, choice checked |
| [3](iphone-3-incomplete-arabic-rejected-english-kept.jpg) | Incomplete Arabic catalog: failure card, English still checked |
| [4](iphone-4-removed-arabic-cached-copy-notice.jpg) | Arabic removed by the site: cached Arabic kept, notice says the last downloaded copy is shown; Back on the right |
| [5](iphone-5-removed-arabic-no-cache-english-notice.jpg) | Arabic removed, no cache: English shown, notice says so and that the choice is kept |
| [6](iphone-6-arabic-rtl-cards-explicit-choice.jpg) | Explicit Arabic on an Arabic device: Cards feed mirrored, mixed-direction content |
| [7](iphone-7-arabic-composer-landscape.jpg) | Arabic composer in landscape with mixed text |

iPad screenshots of the five new journeys from the independent review are in [../2026-10-15-manual-language-independent-review](../2026-10-15-manual-language-independent-review/).

## Raw evidence

Logs and result bundles are on the external volume under the worktree's ignored `.build/results/`: `final-full-iphone.{log,xcresult}`, `final-ipad.{log,xcresult}`, `run1-full-iphone.*`, `run2-targeted-iphone.*`, `run3-rotation-iphone.*`, `backend-rspec.log`, `live-probe.txt`. Compressed copies of the final logs are in this folder.

## Known limits found

- The failure card says "Check your connection" for every failed selection, including a catalog that downloaded but failed validation. The outcome is correct (nothing changes, retry offered); the wording does not distinguish the cause.
- Apple-provided strings follow the app's iOS localization (English only); not separately verified.

## Gates

Merge gates E2 (deploy the plugin and verify it live) and E3 (a live non-English interface) are open. E3 needs a non-English language enabled on the live site. For Arabic that requires native review (E4) first, so the merge depends on E4 or on another approved language. Release-only gates E4 (native Arabic review), E6 (physical-device VoiceOver) and E7 (terminology agreement) stay open. See [acceptance](../../localization-acceptance.md).
