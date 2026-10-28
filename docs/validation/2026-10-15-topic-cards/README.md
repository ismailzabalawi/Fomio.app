# Native topic cards: Compact and Cards — 2026-10-15

Xcode 27.0, Debug Fomio scheme, Simulator only. Backend reference rechecked at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`; no backend changes, no live writes, no credentials. Design reference: [topic card prototype](../../design/topic-card-prototype.md) and its 2026-10-07/08 local captures (the Claude Design page was not reopened in this pass).

## Devices

| Device | OS | Use |
| --- | --- | --- |
| iPhone 17 Pro `E89BA4AD-5D17-4A81-86E6-D08AD23A19E8` | iOS 26.1 | Full unit + UI suite; feed UI suite; manual anchor checks |
| iPad Pro 11-inch (M5) `4D6E1977-E6DA-418C-9D4D-7EA81187AEC8` | iOS 26.1 | Feed appearance UI suite (regular width, sidebar-adaptable tabs) |
| iPhone 16e `99DD18D9-FADD-4080-A776-EA1DEA882783` | iOS 26.1 | Live guest read of `https://meta.fomio.app` (anonymous GETs only), narrowest installed phone |

## Results (final code)

- **Full suite, iPhone 17 Pro:** 87 unit tests (4 opt-in `LiveDiscourseTests` skipped) and 33 UI tests (1 opt-in live UI test skipped), 0 failures.
- **`FeedAppearanceUITests`, iPad Pro 11:** 6/6 passed.
- **`TopicCardTests`** (in the unit total): `image_url` HTTPS/relative/insecure/credential/null mapping and no fixture photos in live data; Original Poster versus last poster, absent author omitted, zero replies kept; `unicode_title` preferred only when sent; activity/replies wording; text direction; anchor placement math.

`FeedAppearanceUITests` (fictional `--card-cases` fixtures):

| Test | Verifies |
| --- | --- |
| `testMenuSwitchesBothWaysAndPersistsAcrossRelaunch` | Compact default; Search/Create retained; menu checkmark state; Compact → Cards; relaunch keeps Cards; Cards → Compact; relaunch keeps Compact |
| `testSwitchKeepsMidFeedTopicAnchorBothDirections` | With page 2 loaded, a mid-feed topic stays within 28pt across each switch and within 6pt after the round trip; a partly hidden top topic remains the first visible topic after both switches |
| `testCardsSurviveCategoryAndTopicBack` | Category label is a separate ≥44pt target; category feed uses Cards; category Back and topic Back (unavailable fixture topic) restore Home position within 3pt |
| `testSwitchKeepsPaginationErrorAndLoadedPages` | "Couldn't load more" and loaded topics survive switching; retry loads page 2; it survives switching back; real topic → Back keeps appearance |
| `testCardCasesOmitAbsentFieldsAndKeepSeparateTargets` | VoiceOver labels include Pinned, original author, "No replies yet", spoken activity; no nested buttons; sparse topic omits author/activity; failed media drops to text; long title with photo in both appearances |
| `testDarkAccessibilityTextAndRightToLeftCaptures` | Dark + AX3, Arabic locale + RTL, Teal dark theme in both appearances (captures) |

Manual Simulator checks: the native menu opens from the toolbar ellipsis with icons and checkmark. Arabic titles align right in an English UI. Live guest Compact/Cards render real deployed `image_url` thumbnails, actual category identities with parent › child, original authors, "No replies yet", "Active … ago" and the 👋 `unicode_title`.

## Defects found and fixed during validation

- Reassigning the bound scroll anchor after placement re-scrolled the topic to the top; removed.
- Negative `UnitPoint` scroll anchors are clamped; partly hidden anchors are now placed through the following topic.
- Initials avatar overflowed its 20pt circle at AX3; omitted at accessibility sizes.
- iPad + AX3 moves Create and options into the system More overflow; the options menu now has a titled label, so it stays named there (test opens it through the overflow).
- Live excerpts kept source line breaks (blank preview lines); collapsed to one paragraph. Raw `:wave:` titles replaced by `unicode_title`.

## Captures

Exported from the final passing result bundles (downscaled), plus two live guest screenshots: menu, Cards, relaunched Cards checked, mid-feed anchor, partly hidden anchor Cards/Compact, pagination error retained, category feed, long title Compact/Cards, dark AX3 Compact/Cards, Arabic RTL Compact/Cards, Teal dark Compact/Cards, iPad menu, long title Cards, category, dark AX3, Arabic, Teal dark, live guest Compact/Cards.

## Limits

- Simulator only; no physical device, real VoiceOver navigation session, Voice Control or contrast audit. Accessibility is inferred from XCUITest element labels, frames and captures.
- Narrowest device tested is iPhone 16e (390pt); 320pt layouts and Split View/Slide Over were not exercised.
- Reduce Motion: switching uses no animation, so there is no motion to reduce; the setting itself was not toggled.
- The iOS 26.1 menu does not display the "Feed appearance" section title above the inline picker.
- Near the end of loaded content the system clamps scroll offset, so switching to the shorter Compact layout there can move the anchor down.
- Live checks are guest-only: member responses, secure/login-required media, CDN-hosted media and category-feed media were not verified. The live check ran before the final small anchor-filter change; that change is covered by the final simulator suites.
- The `--card-cases` topics have no posts, so opening them shows the unavailable state, which serves as the "unavailable-after-tap" case.
- Not uploaded to TestFlight; nothing committed or pushed.
