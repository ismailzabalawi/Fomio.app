# Localization acceptance checklist

Branch `claude/fomio-localization-impl-48ecab`, based on `main` at `3029737` (build 0.8.0 (4), topic cards and category identities). Evidence date 2026-10-15. Xcode 27.0, iOS 26.1 simulators. Status values: **Pass** (verified as described), **Blocked** (prerequisite missing), **Manual pending** (needs a person or device).

Fixture catalogs are served by `FixtureLocalizationTransport` in Debug builds. They prove app behavior against the proposed contract, **not** the deployed backend.

## A. Scope and catalog

| # | Requirement | Evidence | Status |
| --- | --- | --- | --- |
| A1 | Every visible string and accessibility message uses a semantic key (SwiftUI, UIKit/TextKit composer, errors/recovery, navigation, dates/counts, plurals) | `LocalizationCoverageTests.testInterfaceCallsHaveNoHardCodedCopy` scans `Fomio/**/*.swift` for literal copy in interface calls; `testEveryUsedKeyExistsAndNoCatalogKeyIsOrphaned` | Pass |
| A2 | Bundled English is the only bundled language and is complete | `Fomio/Resources/Localization/fomio-catalog-en.json` (481 keys); `ar.lproj`/`en.lproj` removed; Release excludes `catalogs` (§E5) | Pass |
| A3 | Exact Discourse keys reused where meaning matches | `Localization/manifest.json`: 35 mapped keys, each checked at deployed `7b4f0970` and local `d4296c5e` with equal English values; Arabic values equal deployed Discourse Arabic | Pass |
| A4 | Fomio-only phrases have maintained translations | `Localization/catalogs/ar.json` (481 keys). Agent-authored; native Arabic review required before release | Pass (review pending, §F) |
| A5 | Override policy recorded; Byte/Hub not blindly applied | Manifest `terminology`; [strategy](localization-strategy.md#terminology-and-override-policy) | Pass |
| A6 | Server content (names, posts, usernames) stays server-owned with its own direction | `contentDirection(_:)` on post/quote/title/search/notification/profile text; arguments isolated with FSI/PDI | Pass |

## B. Catalog validation and runtime

| # | Requirement | Evidence | Status |
| --- | --- | --- | --- |
| B1 | Required keys, placeholders, plurals validated before activation | `testValidatorRejectsIncompatibleCatalogs` (16 rejection cases incl. live `js.hubs.all` bug), `testValidatorAcceptsReorderedPlaceholdersAndUnknownExtraKeys`, `testBundledEnglishAndMaintainedArabicAreCompleteAndCompatible` | Pass |
| B2 | Arabic plural rules (zero/one/two/few/many/other) and locale number formatting | `testArabicPluralRulesAndFormattedCounts` | Pass |
| B3 | Mixed-direction arguments | `testArgumentsKeepTheirOwnDirection` | Pass |
| B4 | Only languages the site offers *and* the app can validate are listed (complete, plural rules, direction), English first | `testAutonymNamesALanguageTheSiteNoLongerLists`, `testFailedIncompleteAndUnsupportedSelectionsChangeNothing`; UI `testArabicDeviceFreshInstallStaysEnglishAfterCatalogDiscovery` (fixture fr and de rows absent) | Pass |
| B5 | English on cold offline first launch; failed selection leaves choice/catalog intact | `testColdOfflineLaunchShowsEnglishAndSelectionFailsWithoutChangingChoice`; UI `testColdOfflineFirstLaunchShowsCompleteEnglish`, `testFailedSelectionKeepsEnglishAndOffersRetry` | Pass |
| B6 | Cached Arabic used immediately offline | `testCachedArabicActivatesImmediatelyOfflineWithoutNetwork`; UI `testWarmOfflineLaunchUsesCachedArabicImmediately` (offline transport, Arabic within 3 s) | Pass |
| B7 | Stale refresh at 24 h with ETag; 304 renews | `testFreshCacheSkipsNetworkStaleCacheRevalidatesWithETagAnd304KeepsCatalog` | Pass |
| B8 | Changed site-text revision shows on next successful refresh | `testChangedOverrideRevisionAppearsOnNextSuccessfulRefresh`; UI `testChangedSiteOverrideAppearsAfterRefresh` | Pass |
| B9 | Malformed/partial/5xx keep last good catalog; corrupt cache deleted, never shown | `testMalformedOrPartialResponsesKeepLastGoodCatalog`, `testCorruptedCacheIsDeletedAndEnglishShown`; UI `testIncompleteServerCatalogIsRejectedAndEnglishRemains` | Pass |
| B10 | Locale switching changes catalog, formatting locale and direction together | `testExplicitSelectionPersistsOnlyValidatedChoicesAcrossRelaunchAndOffline`; UI `testSwitchingLanguageKeepsNavigationDraftsAndMirrorsLayout` | Pass |
| B11 | No automatic language: fresh install is English after catalog discovery on an Arabic device, with site `default_locale` ar and a member locale ar; no device-language row | `testFreshInstallStaysEnglishAfterCatalogDiscoveryRegardlessOfDeviceSiteOrMemberLocale`; UI `testArabicDeviceFreshInstallStaysEnglishAfterCatalogDiscovery` (incl. relaunch) | Pass |
| B12 | Retain current + one recent language | `testEvictionKeepsCurrentAndOneRecentLanguage` | Pass |
| B13 | Site/relative-root/schema/locale isolation | `testCachesAreIsolatedBySiteRelativeRootAndSchema` | Pass |
| B14 | Concurrent refreshes coalesced | `testConcurrentRefreshesShareOneRequest` | Pass |
| B15 | Transport: public conditional GET, relative root, 304/404 mapping, no cookies or member key, configured plugin paths | `testDiscourseTransportSendsConditionalPublicRequestsUnderRelativeRoot` | Pass |
| B16 | Language change does not reset navigation, drafts, editor selection or uploads | UI B10 test on iPhone and iPad (pushed community and discussion kept; kept draft listed). Editor relabels in place (`Coordinator.relabel`) without re-rendering text; the composer sheet is outside the tab container that rebuilds on a direction change. A language change while a composer is open is only possible through a background first download; it was not automated | Pass (navigation, drafts); editor/upload continuity by design, not automated |
| B17 | Explicit selection persists only after validation; relaunch and offline use the last good cache | `testExplicitSelectionPersistsOnlyValidatedChoicesAcrossRelaunchAndOffline`; UI `testExplicitSelectionPersistsAcrossRelaunchAndOffline`, `testWarmOfflineLaunchUsesCachedArabicImmediately` | Pass |
| B18 | Failed, incomplete or unsupported selection changes nothing | `testFailedIncompleteAndUnsupportedSelectionsChangeNothing`; UI `testFailedSelectionKeepsEnglishAndOffersRetry` (incl. relaunch), `testIncompleteServerCatalogIsRejectedAndEnglishRemains` | Pass |
| B19 | Removed language: no auto-switch, no request, choice kept; valid cache kept and shown with an honest notice; missing/corrupt/incompatible cache → English with an English-fallback notice | `testRemovedLanguageKeepsLastGoodCacheWithoutAutoSwitching`, `testOpeningLanguageRevalidatesAFreshCachedIndexAndFindsARemovedLanguage`, `testRemovedLanguageWithMissingCorruptOrIncompatibleCacheShowsEnglishAndKeepsTheChoice`; UI `testRemovedLanguageKeepsCachedCopyAndSaysSo`, `testRemovedLanguageWithoutCacheShowsEnglishAndSaysSo` | Pass |
| B20 | Refresh updates the selected language's wording, never the selection | `testChangedOverrideRevisionAppearsOnNextSuccessfulRefresh`, `testFreshCacheSkipsNetworkStaleCacheRevalidatesWithETagAnd304KeepsCatalog`; UI `testChangedSiteOverrideAppearsAfterRefresh` | Pass |
| B21 | No iOS per-app language competes with the in-app choice | `CFBundleLocalizations` = `[en]` (project.yml/Info.plist); Back direction regressions in `NavigationDirectionUITests` with English and Arabic iOS languages | Pass |

## C. Native UI (simulator)

See [validation record](validation/2026-10-15-localization/README.md) for screenshots, commands and result bundles.

| # | Check | Status |
| --- | --- | --- |
| C1 | iPhone 17: language selection, Home (mixed Arabic/English and long titles), Communities, community feed, About, Discussion, reply composer with mixed text, More menu, search, notifications, Me, Drafts, new-discussion composer, Add block — Arabic RTL; LTR restored after switching back | Pass (screenshots inspected) |
| C2 | iPad Pro 11-inch: the same journeys | Pass (screenshots inspected) |
| C3 | Accessibility text sizes in Arabic keep composer controls reachable | Pass (iPhone and iPad) |
| C4 | Accessibility labels localized and argument-isolated (topic summary, composer fields, Post) | Pass (asserted; hierarchy dumps) |
| C5 | Existing regression suites on the final tree | Pass: iPhone 17 108 unit/contract + 40 UI, 0 failures; iPad localization + feed appearance 13 UI, 0 failures. Other existing UI tests not rerun on iPad |
| C6 | Release build bundles English only | Pass |

## D. Preserved behavior

Topic cards/appearances, category identities/hierarchy, authentication gates, protected drafts, posting outcomes and photo uploads are covered by the pre-existing unit and UI suites (C5). Strings changed only through keys whose English values are identical to before, except: proper plurals ("1 like" instead of "1 likes" in accessibility labels), the community breadcrumb chevron now follows the interface direction, and `ContentUnavailableView.search` was replaced with catalog text.

## E. Gates

Merge gates (required before merging this branch):

| # | Gate | Status |
| --- | --- | --- |
| E1 | Backend catalog endpoint per [contract](localization-catalog-contract.md) implemented with request specs, client-equivalent validation, English-only default allowlist, member-header compatibility with the deployed revision | **Pass (local)**: plugin on backend branch `fomio/app-locale-catalog` (`245a6b63e10`, `6eca1a33a4a`), 46 examples, 0 failures; awaiting independent review |
| E2 | Plugin deployed; anonymous and signed-in verification on the live site (200, ETag/304, no `X-Discourse-Username`, only allowlisted locales) | **Blocked**: deployment not authorized; live paths 404 at 7b4f0970 (2026-10-15T17:46Z) |
| E3 | Live non-English interface on a device, selected in Me › Language from the deployed endpoint (requires a language enabled on the live site, which in turn requires E4 for Arabic) | **Blocked** on E2 (and the enabling decision) |
| E5 | Release build contains no `catalogs` folder | Pass |

Release-only gates (required before offering a language other than English to members; not waived):

| # | Gate | Status |
| --- | --- | --- |
| E4 | Native-speaker review of `Localization/catalogs/ar.json`, then add `ar` to `fomio_app_locales` | Manual pending |
| E6 | VoiceOver walk-through in Arabic on a physical device; Increase Contrast/Reduce Motion | Manual pending |
| E7 | Product agreement on the terminology policy (native discussion/community vs the forum's Byte/Hub/Teret overrides) | **Open**: documented implementation choice, explicit in the manifest, not yet agreed |

The branch is **not merged**: E2 and E3 are open.

## F. Independent review of 6162c57 (2026-10-15)

| # | Finding | Resolution and evidence | Status |
| --- | --- | --- | --- |
| F1 | Retained app errors resolved at catch time, not render time | `DisplayError` (semantic keys rendered on display, server/system text verbatim); all retained error states converted; a failed feed waits for an explicit retry. Unit + UI regressions on iPhone and iPad | Pass |
| F2 | UIKit direction `.unspecified` for LTR, skipped on the initial fallback | Explicit `.forceLeftToRight`/`.forceRightToLeft` on every activation; composer cards set direction; UI regressions with Arabic iOS language (cold English fallback, Arabic → English) | Pass (Back chevron completed in F2b) |
| F2b | Re-review of b8eb0b0: system Back chevron reversed when iOS and interface directions differ | Targeted back indicator for mismatched directions only; native Back, label, tap/edge-swipe and return anchor verified in both mismatches, cold launch and switching (`NavigationDirectionUITests`) | Pass ([record](validation/2026-10-15-rereview-fixes/README.md)) |
| F3 | Failed topic media never recovered | `MediaLoadState` (re-review: a recovered image keeps its load attempt across later refreshes, verified with fixture request counts); restored-source and replacement paths verified in Compact and Cards, English and Arabic accessibility3, iPhone and iPad | Pass |

Details, commands, counts and screenshots: [review-fixes validation](validation/2026-10-15-review-fixes/README.md). Gate status at that review is superseded by §E.
