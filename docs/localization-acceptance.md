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
| B4 | Apple language → Discourse locale mapping | `testLocaleMatchingUsesExplicitMapping` | Pass |
| B5 | English on cold offline first launch; failed selection leaves preference/catalog intact | `testColdOfflineLaunchShowsEnglishAndSelectionFailsWithoutChangingPreference`; UI `testColdOfflineFirstLaunchShowsCompleteEnglish` | Pass |
| B6 | Cached Arabic used immediately offline | `testCachedArabicActivatesImmediatelyOfflineWithoutNetwork`; UI `testWarmOfflineLaunchUsesCachedArabicImmediately` (offline transport, Arabic within 3 s) | Pass |
| B7 | Stale refresh at 24 h with ETag; 304 renews | `testFreshCacheSkipsNetworkStaleCacheRevalidatesWithETagAnd304KeepsCatalog` | Pass |
| B8 | Changed site-text revision shows on next successful refresh | `testChangedOverrideRevisionAppearsOnNextSuccessfulRefresh`; UI `testChangedSiteOverrideAppearsAfterRefresh` | Pass |
| B9 | Malformed/partial/5xx keep last good catalog; corrupt cache deleted, never shown | `testMalformedOrPartialResponsesKeepLastGoodCatalog`, `testCorruptedCacheIsDeletedAndEnglishShown`; UI `testIncompleteServerCatalogIsRejectedAndEnglishRemains` | Pass |
| B10 | Locale switching changes catalog, formatting locale and direction together | `testSwitchingLanguagesPersistsPreferenceAndChangesCatalogTogether`; UI `testSwitchingLanguageKeepsNavigationDraftsAndMirrorsLayout` | Pass |
| B11 | Device language followed by default among complete site languages | `testDeviceLanguageFollowsSiteIndexAndIgnoresIncompleteLanguages` | Pass |
| B12 | Retain current + one recent language | `testEvictionKeepsCurrentAndOneRecentLanguage` | Pass |
| B13 | Site/relative-root/schema/locale isolation | `testCachesAreIsolatedBySiteRelativeRootAndSchema` | Pass |
| B14 | Concurrent refreshes coalesced | `testConcurrentRefreshesShareOneRequest` | Pass |
| B15 | Transport: public conditional GET, relative root, 304/404 mapping, no member key, no configured path yet | `testDiscourseTransportSendsConditionalPublicRequestsUnderRelativeRoot` | Pass |
| B16 | Language change does not reset navigation, drafts, editor selection or uploads | UI B10 test on iPhone and iPad (pushed community and discussion kept; kept draft listed). Editor relabels in place (`Coordinator.relabel`) without re-rendering text; the composer sheet is outside the tab container that rebuilds on a direction change. A language change while a composer is open is only possible through a background first download; it was not automated | Pass (navigation, drafts); editor/upload continuity by design, not automated |

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

## E. Release and backend gates

| # | Gate | Status |
| --- | --- | --- |
| E1 | Backend catalog endpoint per [contract](localization-catalog-contract.md) implemented with request specs | **Blocked**: needs an authorized backend task |
| E2 | Endpoint deployed; anonymous and member verification on the live site; Info paths configured | **Blocked** on E1 and deployment |
| E3 | Live non-English interface on a device | **Blocked** on E2 |
| E4 | Native-speaker review of `Localization/catalogs/ar.json` | Manual pending |
| E5 | Release build contains no `catalogs` folder | Pass |
| E6 | VoiceOver walk-through in Arabic on a physical device; Increase Contrast/Reduce Motion | Manual pending |
| E7 | Product agreement on the terminology policy (native discussion/community vs the forum's Byte/Hub/Teret overrides) | **Open**: documented implementation choice, not yet agreed |

The branch is **not merged**: the task's merge condition requires live contract verification (E1–E3).

## F. Independent review of 6162c57 (2026-10-15)

| # | Finding | Resolution and evidence | Status |
| --- | --- | --- | --- |
| F1 | Retained app errors resolved at catch time, not render time | `DisplayError` (semantic keys rendered on display, server/system text verbatim); all retained error states converted; a failed feed waits for an explicit retry. Unit + UI regressions on iPhone and iPad | Pass |
| F2 | UIKit direction `.unspecified` for LTR, skipped on the initial fallback | Explicit `.forceLeftToRight`/`.forceRightToLeft` on every activation; composer cards set direction; UI regressions with Arabic iOS language (cold English fallback, Arabic → English) | Pass for app-owned UIKit; system back-chevron glyph follows the iOS language (recorded limit) |
| F3 | Failed topic media never recovered | `MediaFailure` scoped to source + refresh generation; restored-source and replacement paths verified in Compact and Cards, English and Arabic accessibility3, iPhone and iPad | Pass |

Details, commands, counts and screenshots: [review-fixes validation](validation/2026-10-15-review-fixes/README.md). Gates E1–E4, E6 and E7 remain open; the branch is not merged.
