# Interface localization — simulator validation, 2026-10-15

Source: branch `claude/fomio-localization-impl-48ecab` (from `main` `3029737`). Xcode 27.0 (27A266a), iOS 26.1 simulators: iPhone 17 and iPad Pro 11-inch (M5). Debug builds in fixture mode; catalogs come from `FixtureLocalizationTransport` (maintained Arabic file, bundled English), **not** from a deployed backend. The simulators' device language is English; Arabic was chosen in the app or with `--language ar`.

## Commands

```sh
xcodegen generate
xcodebuild -project Fomio.xcodeproj -scheme Fomio -destination 'platform=iOS Simulator,name=iPhone 17' test
xcodebuild -project Fomio.xcodeproj -scheme Fomio -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' \
  -only-testing:FomioUITests/LocalizationUITests -only-testing:FomioUITests/FeedAppearanceUITests test
xcodebuild -project Fomio.xcodeproj -scheme Fomio -configuration Release -destination 'generic/platform=iOS Simulator' build
```

## Results

| Run | Result |
| --- | --- |
| Baseline before changes (iPhone 17, `main` source) | 87 unit/contract (4 live skipped) and 33 UI (1 live skipped), 0 failures |
| Final full suite, iPhone 17 | **108 unit/contract (4 live skipped), 40 UI (1 live skipped), 0 failures**; no compiler warnings |
| iPad Pro 11-inch: `LocalizationUITests` + `FeedAppearanceUITests` | **13 UI, 0 failures** |
| After the last two polish fixes (language autonym, composer context direction; no shared-code change), iPhone 17: all unit tests + `LocalizationUITests` | **108 unit/contract (4 skipped) and 7 UI, 0 failures**; affected iPhone screenshots refreshed from this run |
| Release build | Succeeded. Bundle contains `fomio-catalog-en.json` only (no `catalogs/`, no `.lproj`); `CFBundleLocalizations` = en, ar; no `FomioLocaleIndexPath`/`FomioLocaleCatalogPath` |

The pre-existing iPad UI tests other than feed appearance were not run on iPad in this pass. Result bundles were local scratch artifacts and are not committed.

## Defects found by these checks and fixed

1. A breadcrumb made only of Latin names ran left-to-right inside the Arabic UI (isolated arguments are neutral). RTL messages that begin with an argument now start with a right-to-left mark.
2. The native UIKit More menu showed Arabic text in a left-to-right layout. The `UIView` appearance direction now follows the catalog.
3. Composer title/body placeholders were left-aligned in Arabic: a representable's environment direction did not reflect the interface; the editor now reads the catalog direction.
4. iPad: after switching Arabic → English the top tab bar stayed mirrored. The tab container is rebuilt on a direction change; tab paths and drafts were verified to survive on iPhone and iPad.
5. Multi-line English community descriptions were right-aligned in Arabic; they now keep their own direction.
6. The cold-offline Language screen showed the raw code "ar"; it now shows the language's own name until the site list loads.
7. The reply composer's context title (community content) was right-aligned in Arabic; it keeps its own direction.

## Observed limits (not defects in app code)

- Apple-owned controls follow the iOS language: the search field's "Close"/"Clear text" and the iPad tab bar overflow "More" stayed English with Arabic chosen in-app on an English device.
- The iPad top tab bar paginates at accessibility sizes; "Me" moves to the next page.
- Discourse server messages would still be English (site locale) — not exercised here, fixtures only.

## Screenshots

Every image was inspected. `iphone-*` and `ipad-*` pairs exist for each item:

- Language screen before/after switching: `*-language-screen-english.jpg`, `*-language-screen-after-switching-to-arabic.jpg`
- State kept across the switch: `*-community-feed-kept-after-language-change-arabic.jpg`, `*-discussion-kept-after-language-change-arabic-rtl.jpg`, `*-drafts-arabic.jpg`
- Offline and catalog handling: `*-warm-offline-launch-from-cached-arabic.jpg`, `*-cold-offline-launch-english-with-arabic-pending.jpg`, `*-incomplete-arabic-response-rejected.jpg`, `*-english-site-override-revision-applied.jpg`
- Primary screens in Arabic: `*-home-with-pinned-arabic-titled-and-long-topics-arabic-ui.jpg` (mixed Arabic/English titles, long title), `*-home-further-down-arabic.jpg`, `*-communities-arabic.jpg`, `*-community-feed-arabic.jpg`, `*-community-about-arabic.jpg`, `*-discussion-arabic.jpg`, `*-search-results-arabic.jpg`, `*-notifications-arabic.jpg`, `*-me-arabic.jpg`
- Composer: `*-reply-composer-mixed-arabic-and-english-text.jpg`, `*-composer-more-menu-arabic.jpg`, `*-new-discussion-composer-arabic.jpg`, `*-add-block-arabic.jpg`
- Accessibility text sizes: `*-home-arabic-accessibility-text.jpg`, `*-discussion-arabic-accessibility-text.jpg`, `*-composer-arabic-accessibility-text.jpg`

Accessibility labels were asserted in tests (topic summary containing «بدأه», composer body «نص الرد», title «العنوان», Post «نشر») and read from hierarchy dumps; a full VoiceOver walk-through on a device remains manual.
