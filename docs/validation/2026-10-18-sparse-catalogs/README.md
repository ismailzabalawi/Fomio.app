# Automatic Discourse translation reuse: sparse overlays and English fallback (schema 2)

Date 2026-10-18. App branch `claude/fomio-localization-impl-48ecab` (unmerged; `main` untouched at `b62aef5`). Backend branch `fomio/app-locale-catalog` in `/Volumes/Develop/Projects/Dicourse-worktrees/fomio-app-locales`, based on Discourse `d4296c5`. **Local only: nothing published, deployed or changed on the live site.** Xcode 27.1, iOS 26.1, dedicated simulators "Fomio L10n iPhone 17" (`57501E8D…`) and "Fomio L10n iPad Pro 11" (`2F25999F…`), created so these runs don't contend with the Reporting & Safety builds.

## What changed

The full per-language catalog requirement is replaced by server-side assembly:

- **English** is the default and the fallback: the app's bundled English, plus a valid `en` site-text override on a mapped key.
- **Per key, for other locales:** (1) a mapped key uses that locale's own Discourse translation (its own override first when valid; a regional locale never borrows its parent language); (2) a Fomio key uses the sparse overlay `Localization/catalogs/<locale>.json` (Fomio keys only; Arabic is the only overlay); (3) otherwise English, listed in `fallback`. An invalid translation (markup, raw key, wrong placeholders, plural form outside the locale's categories, no `other`, `other` without the count) is replaced by English.
- **Plural categories** are Discourse's CLDR keys per locale. The app implements all 15 integer families of Discourse's 49 client locales; a translated plural needs `other` (a form it omits is shown as `other`, as Discourse does); fallback plurals use English rules and English digits.
- **Mixed text:** English fallback inside a right-to-left catalog is isolated as one left-to-right run (U+2066…U+2069), with its arguments isolated left to right. A fragment composed into another message (compact age, style name) names its container (`within:`) and is English whenever the container is. This was found in the first Hebrew screenshots ("Active דקות 2 ago"), fixed, and is now guarded by a unit test and a source check.
- **Manual choice unchanged:** English first launch; only Me › Language changes the language; the plugin's own allowlist `fomio_app_locales` (default `en`) decides what is offered; nothing is enabled automatically. Me › Language marks languages with English fallback "Partly translated: some text appears in English".
- **Unsupported cases are explicit:** a locale without Discourse plural rules is not offered by the server; a locale whose categories differ from the app's rules, or that is incomplete, is not listed by the app.
- **Schema 2:** the app asks for `/fomio/app-locales/2/…`. The live site runs v0.1.1 (schema 1), so an app build from this branch gets 404 there and offers English only ([live-schema-check.txt](live-schema-check.txt)) until v0.2.0 is deployed.

## Mappings (49 of 482 keys)

Every mapping was reviewed for meaning in context, not only wording: the Fomio key's usage in the app, the Discourse key's purpose, and Discourse's values in ar, ru, fr, de, he and ja. English equivalence was checked against `client.en.yml` at `d4296c5` and deployed `821e9e2f` (and is a backend spec). 14 were added in this round (35 → 49): 17 were chosen, then 3 withdrawn because they would make Arabic worse (Latin comma; English-only table keys).

| Fomio key | Discourse key | Note |
| --- | --- | --- |
| `auth.gate.reply.title` | `js.embed_mode.signin_flow.sign_in_to_reply` | Prompt to sign in before replying (embed sign-in flow) |
| `common.back` | `js.back_button` | mapped 2026-10-15 |
| `common.cancel` | `js.cancel` | mapped 2026-10-15 |
| `common.clear_search` | `js.search.clear_search` | mapped 2026-10-15 |
| `common.dismiss` | `js.software_update_prompt.dismiss` | Button closing a transient notice; js.notifications.dismiss_confirmation.dismiss rejected (ru: 'mark as read') |
| `common.done` | `js.done` | mapped 2026-10-15 |
| `common.edit` | `js.edit` | mapped 2026-10-15 |
| `common.more` | `js.more` | mapped 2026-10-15 |
| `common.ok` | `js.ok_value` | mapped 2026-10-15 |
| `common.try_again` | `js.errors.buttons.again` | Retry button after a failed load; Discourse English is title case, English itself keeps the app's wording |
| `community.about` | `js.about.simple_title` | mapped 2026-10-15 |
| `composer.block.date.timezone` | `js.user.timezone` | Time zone field label |
| `composer.destination.required` | `js.form_kit.errors.required` | Required-field marker |
| `composer.discard` | `js.composer.discard` | mapped 2026-10-15 |
| `composer.format.bold` | `js.keyboard_shortcuts_help.composing.bold` | mapped 2026-10-15 |
| `composer.format.italic` | `js.keyboard_shortcuts_help.composing.italic` | mapped 2026-10-15 |
| `composer.insert` | `js.composer.link_dialog_action` | mapped 2026-10-15 |
| `composer.link` | `js.composer.link_title` | mapped 2026-10-15 |
| `composer.link.text` | `js.composer.link_optional_text` | mapped 2026-10-15 |
| `composer.rich_text` | `js.composition_mode.rich` | mapped 2026-10-15 |
| `composer.style.heading` | `js.composer.heading_level_n` (placeholders {'levelNumber': 'level'}) | Composer heading menu item for level N |
| `composer.style.list` | `js.composer.ulist_title` | mapped 2026-10-15 |
| `composer.style.paragraph` | `js.composer.heading_level_paragraph` | mapped 2026-10-15 |
| `composer.undo_action.insert_link` | `js.composer.link_dialog_title` | mapped 2026-10-15 |
| `discussion.continue_thread` | `js.nested_replies.continue_thread` | mapped 2026-10-15 |
| `discussion.more_replies` | `js.nested_replies.load_more_children_generic` | mapped 2026-10-15 |
| `discussion.no_replies` | `js.nested_replies.no_replies` | mapped 2026-10-15 |
| `discussion.replies` | `js.review.replies` | Reply count of a discussion; js.nested_replies.collapsed_replies rejected (he 'other' lacks the count, ar uses 'of replies') |
| `discussion.replies_heading` | `js.replies` | mapped 2026-10-15 |
| `drafts.kind.reply` | `js.topic.reply.title` | mapped 2026-10-15 |
| `drafts.resume` | `js.drafts.resume` | mapped 2026-10-15 |
| `feed.latest` | `js.filters.latest.title` | mapped 2026-10-15 |
| `language.title` | `js.sidebar.sections.custom.localizations.locale` | Field/screen label for a language |
| `me.drafts` | `js.drafts.label` | mapped 2026-10-15 |
| `notifications.unread` | `js.user.user_notifications.filters.unread` | Unread notifications state |
| `post.like` | `js.post.controls.like_action` | mapped 2026-10-15 |
| `post.likes` | `js.post.likes_popup.title` | Like count of a post |
| `post.quote` | `js.post.quote_reply` | mapped 2026-10-15 |
| `post.reply` | `js.topic.reply.title` | mapped 2026-10-15 |
| `post.save` | `js.bookmarks.save` | Save (bookmark) a post |
| `post.share` | `js.post.controls.share_action` | mapped 2026-10-15 |
| `profile.title` | `js.user.profile` | mapped 2026-10-15 |
| `search.title` | `js.search.title` | mapped 2026-10-15 |
| `tab.home` | `js.home` | mapped 2026-10-15 |
| `tab.notifications` | `js.user.notifications` | mapped 2026-10-15 |
| `time.compact.days` | `js.dates.tiny.x_days` | Compact relative age, days |
| `time.compact.hours` | `js.dates.tiny.about_x_hours` | Compact relative age, hours |
| `time.compact.minutes` | `js.dates.tiny.x_minutes` | Compact relative age, minutes |
| `topic.pinned` | `js.topic_statuses.pinned.title` | mapped 2026-10-15 |

### Reviewed and rejected (manifest `rejected_candidates`)

| Candidate | Reason rejected |
| --- | --- |
| `common.dismiss (alt)` | js.notifications.dismiss_confirmation.dismiss: ru 'Пометить прочитанными' (mark as read) — context-specific |
| `common.list_separator` | js.word_connector.comma: Discourse's Arabic value is the Latin ', ' where Arabic needs '، ' |
| `common.remove` | js.drafts.remove / js.user.invited.remove / access permission remove: context-specific, no generic key |
| `common.save` | js.save is 'Save Changes'; js.bookmarks.save is bookmark-specific (used for post.save instead) |
| `community.fallback_name` | js.badges.badge_grouping.community.name: badge group, and category terminology is Fomio-owned |
| `composer.block.code` | js.user_api_key.device.code / js.user.second_factor.label: authentication codes |
| `composer.block.details.summary` | js.user.summary.title: a user's summary page |
| `composer.block.poll.option(s)` | js.shortcut_modifier_key.option (⌥ key) / js.composer.options (composer menu) |
| `composer.block.table.add_column` | js.composer.table.add_column: translated in Discourse English only at d4296c5 and 821e9e2f; mapping would replace maintained translations with English |
| `composer.block.table.add_row` | js.composer.table.add_row: translated in Discourse English only at d4296c5 and 821e9e2f; mapping would replace maintained translations with English |
| `composer.destination.change` | js.upload_selector.change: upload context |
| `composer.inserter.advanced` | js.category.advanced: category settings tab |
| `composer.post` | js.review.types.reviewable_post.title: noun in review queue, Fomio key is the Post action |
| `composer.posting` | js.groups.manage.interaction.posting: permission noun, Fomio key is progress |
| `composer.style.text` | js.composer.link_optional_text / raw email text part: different meanings |
| `composer.title_field` | js.composer.title_placeholder_redesign: absent at deployed 821e9e2f; js.user.title.title is a user title |
| `composer.undo / undo_action.*` | js.review...undo, js.edit, js.composer.link_dialog_action: verbs or other contexts; Fomio keys name undo actions |
| `content.details` | group log / auth token details: other contexts |
| `discussion.no_replies_yet` | js.nested_replies.no_replies: Discourse English ends with a period, which would change composed card text |
| `discussion.replies (alt)` | js.nested_replies.collapsed_replies: he 'other' lacks {count} ('two replies'), ar uses 'من الردود'; js.review.replies used |
| `language.row_label / me.row_count / notifications.row_a11y_age` | js.notifications.liked_by_2_users: same punctuation pattern only |
| `me.saved / post.saved` | js.review.settings.saved: 'settings saved' confirmation, different meaning |
| `post.member_fallback` | js.user.invited.invite_roles.summary.role_member: invite role |
| `post.unavailable.nav_title` | js.category.choose_type.unavailable: category type picker |
| `time.compact.now` | js.time_shortcut.now: scheduling shortcut, not a relative age |

## Coverage for every Discourse client locale (real builder, Discourse `d4296c5`)

From [coverage-49-locales-d4296c5.json](coverage-49-locales-d4296c5.json) (`script/export_catalogs.rb coverage`; the checkout reports `7f287f9e`, which is `d4296c5` plus the plugin commits). All 49 assemble completely. Without an overlay a language gets 29–52 Discourse strings and the rest of Fomio's copy stays English; that is the honest state, and the app says so. Arabic is fully covered (Discourse + overlay); its overlay is agent-authored and needs native review.

| Locale | Dir | Plural categories | From Discourse | Overlay | English fallback | Translated |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| ar | rtl | zero, one, two, few, many, other | 49 | 433 | 0 | 100% |
| be | ltr | one, few, many, other | 29 | 0 | 453 | 6% |
| bg | ltr | one, other | 35 | 0 | 447 | 7% |
| bs_BA | ltr | one, few, other | 36 | 0 | 446 | 7% |
| ca | ltr | one, other | 36 | 0 | 446 | 7% |
| cs | ltr | one, few, many, other | 44 | 0 | 438 | 9% |
| da | ltr | one, other | 44 | 0 | 438 | 9% |
| de | ltr | one, other | 49 | 0 | 433 | 10% |
| el | ltr | one, other | 49 | 0 | 433 | 10% |
| en | ltr | one, other | — | 0 | 0 | — |
| en_GB | ltr | one, other | 0 | 0 | 482 | 0% |
| es | ltr | one, many, other | 44 | 0 | 438 | 9% |
| et | ltr | one, other | 33 | 0 | 449 | 7% |
| fa_IR | rtl | one, other | 39 | 0 | 443 | 8% |
| fi | ltr | one, other | 44 | 0 | 438 | 9% |
| fr | ltr | one, many, other | 49 | 0 | 433 | 10% |
| gl | ltr | one, other | 38 | 0 | 444 | 8% |
| he | rtl | one, two, many, other | 49 | 0 | 433 | 10% |
| hr | ltr | one, few, other | 44 | 0 | 438 | 9% |
| hu | ltr | one, other | 44 | 0 | 438 | 9% |
| hy | ltr | one, other | 36 | 0 | 446 | 7% |
| id | ltr | other | 29 | 0 | 453 | 6% |
| it | ltr | one, many, other | 44 | 0 | 438 | 9% |
| ja | ltr | other | 44 | 0 | 438 | 9% |
| ko | ltr | other | 39 | 0 | 443 | 8% |
| lt | ltr | one, few, many, other | 39 | 0 | 443 | 8% |
| lv | ltr | zero, one, other | 34 | 0 | 448 | 7% |
| nb_NO | ltr | one, other | 36 | 0 | 446 | 7% |
| nl | ltr | one, other | 46 | 0 | 436 | 10% |
| pl_PL | ltr | one, few, many, other | 49 | 0 | 433 | 10% |
| pt | ltr | one, many, other | 43 | 0 | 439 | 9% |
| pt_BR | ltr | one, many, other | 44 | 0 | 438 | 9% |
| ro | ltr | one, few, other | 42 | 0 | 440 | 9% |
| ru | ltr | one, few, many, other | 46 | 0 | 436 | 10% |
| sk | ltr | one, few, many, other | 43 | 0 | 439 | 9% |
| sl | ltr | one, two, few, other | 38 | 0 | 444 | 8% |
| sq | ltr | one, other | 34 | 0 | 448 | 7% |
| sr | ltr | one, few, other | 33 | 0 | 449 | 7% |
| sv | ltr | one, other | 39 | 0 | 443 | 8% |
| sw | ltr | one, other | 31 | 0 | 451 | 6% |
| te | ltr | one, other | 38 | 0 | 444 | 8% |
| th | ltr | other | 34 | 0 | 448 | 7% |
| tr_TR | ltr | one, other | 46 | 0 | 436 | 10% |
| ug | rtl | one, other | 44 | 0 | 438 | 9% |
| uk | ltr | one, few, many, other | 49 | 0 | 433 | 10% |
| ur | rtl | one, other | 47 | 0 | 435 | 10% |
| vi | ltr | other | 44 | 0 | 438 | 9% |
| zh_CN | ltr | other | 49 | 0 | 433 | 10% |
| zh_TW | ltr | other | 49 | 0 | 433 | 10% |

Deployed-revision difference: comparing the mapped keys' values in all 49 locales between `d4296c5` and deployed `821e9e2f` (2,401 values; [mapped-values-d4296c5-vs-821e9e2.txt](mapped-values-d4296c5-vs-821e9e2.txt)): only Lithuanian differs (6 newly translated, 1 changed). The plugin specs could not run at `821e9e2f` (pnpm 12 tooling, as recorded for v0.1.1).

## Plural rules

`Localization/discourse-plural-truth.json` holds the categories Discourse's own rules (`config/locales/plurals.rb`, unchanged between `d4296c5` and `821e9e2f`) select for counts 0–200 and selected large values in all 49 locales, generated by `Localization/tools/plural-truth.rb`. `testPluralRulesMatchDiscourseForEveryLocale` compares every entry (>10,000 checks). Counts 0, 1, 2, 3, 11, 100 in fixture catalogs:

| Locale | 0 | 1 | 2 | 3 | 11 | 100 |
| --- | --- | --- | --- | --- | --- | --- |
| ar | zero | one | two | few | many | other |
| he | other | one | two | other | other | many (Discourse he omits `many` → `other`) |
| ru | many | one | few | few | many | many |
| pt_BR | one | one | other | other | other | other |
| ja | other | other | other | other | other | other |
| English fallback (any locale) | other | one | other | other | other | other |

## Tests (final source; app diff on top of `78cb843`, backend diff on top of `7f287f9e`)

| Run | Result |
| --- | --- |
| Backend `LOAD_PLUGINS=1 bin/rspec plugins/discourse-fomio-app-locales/spec` (Discourse `d4296c5`) | **44 examples, 0 failures**; syntax_tree and RuboCop clean ([log](sparse-rspec-3.log.gz)) |
| iPhone 17 (dedicated), full scheme | **128 unit/contract (4 live skipped) + 57 UI (4 skipped: the opt-in live tests), 0 failures**, no runner restarts ([log](sparse-final-iphone.log.gz)) |
| iPad Pro 11 (dedicated): `FomioTests` + Localization, FeedAppearance, ReviewFixes, NavigationDirection UI | **128 (4 live skipped) + 27 UI, 0 failures** ([log](sparse-final-ipad.log.gz)) |

New or changed tests: `testPluralRulesMatchDiscourseForEveryLocale`, `testCountMatrixForTranslatedAndFallbackPlurals`, `testFallbackMessagesKeepEnglishDirectionInsideRightToLeftCatalogs`, `testComposedFragmentsFollowTheirSentenceLanguage`, `testComposedFragmentsNameTheirContainer`, `testValidatorChecksAssembledCatalogsAndFallbackAgainstEnglishRules`, `testIndexOffersOnlyLanguagesTheAppCanRenderAndMarksPartialOnes`, `testOverlayCoversOnlyFomioKeysAndFallbackOnlyKeysWithoutValidTranslations`. UI: `testHebrewMixesDiscourseHebrewWithEnglishFallbackRightToLeftAndSurvivesOfflineRelaunch` (partial note, Hebrew + English tabs, right-to-left order, Back on the right, offline relaunch from cache), `testRussianWithoutOverlayUsesDiscourseTextRussianPluralsAndEnglishFallback` (`3 ответа`, `1 ответ`, English "No replies yet"). Existing journeys (cache, ETag/304, offline/relaunch, removed/invalid catalogs, navigation Back/swipe, media recovery, retained errors, feed appearance) were rerun unchanged except: fixture paths, schema 2, the French example replaced by `tlh` (French is now supported), and one Arabic literal now from Discourse (`إعادة المحاولة`). Backend member-header, weak-ETag and 404 specs pass for schema 2.

Fixtures: `Localization/fixtures` (en, ar, he, ru, pt_BR, ja, index) were generated by the real builder (`script/export_catalogs.rb fixtures`), not written by hand. They prove app behavior, **not** a deployed endpoint.

## Screenshots (inspected)

iPhone: [language list](iphone-language-list-with-partly-translated-languages.jpg), [Hebrew language screen](iphone-hebrew-language-screen-mixed-hebrew-and-english.jpg), [Hebrew feed](iphone-hebrew-home-feed-with-english-fallback.jpg) ("Active 2m ago" fully English, reply counts Hebrew), [Hebrew discussion](iphone-hebrew-discussion-mixed-text.jpg), [Russian feed](iphone-russian-home-feed-discourse-russian-plurals-and-english.jpg). iPad: [language list](ipad-language-list-with-partly-translated-languages.jpg), [Hebrew language screen](ipad-hebrew-language-screen-mixed-hebrew-and-english.jpg), [Hebrew feed](ipad-hebrew-home-feed-with-english-fallback.jpg), [Hebrew discussion](ipad-hebrew-discussion-mixed-text.jpg), [Russian feed](ipad-russian-home-feed-discourse-russian-plurals-and-english.jpg).

The Hebrew "discussion" captures show the fixture's unavailable-post screen for that card case (fixture content), not a localization defect; they are kept for the Back placement and mixed English/Hebrew controls.

## Limits and gates

- **Not deployed.** Publishing v0.2.0 and rebuilding are separate, unauthorized steps; until then the live site serves schema 1 and this branch's app shows English only there. E2 must be repeated for v0.2.0 (anonymous and member, compressed 304, no username, 404s).
- **E3** (live non-English selection) still needs an approved language in `fomio_app_locales`. Discourse translations make any locale technically available, but most of Fomio's copy stays English without an overlay; whether a partly translated language should be offered is a product decision.
- **E4** native Arabic review of the overlay; **E6** physical-device VoiceOver (including how isolates read in mixed text); **E7** terminology agreement: all open.
- Discourse translations are used as Discourse ships them (for example Arabic "رد واحد (1)"); their quality is Discourse's.
- A translated sentence can contain an English fragment when the fragment's own translation is missing (none in Arabic today); a fragment is never translated when its sentence is English.
