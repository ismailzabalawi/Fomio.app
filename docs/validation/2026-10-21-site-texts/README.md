# Interface strings as Discourse site texts: plugin v0.3.0

Date: 2026-10-21 (Amman; deployment the evening of 2026-10-21 UTC). Design: [localization-site-text-design.md](../../localization-site-text-design.md). Built as local backend work, then published and deployed with the project owner's authorization. **Status: v0.3.0 (`171fa30`) is live on meta.fomio.app (Discourse `02e1115201f`) and verified anonymously and signed in; see [Deployment](#deployment-and-live-verification).** No live setting or site text was changed.

## What changed

**App repository (this branch)**

- `Localization/tools/site-texts.rb`: `sync` and `check` modes. Reads the bundled English, `Localization/manifest.json` and `Localization/catalogs/<locale>.json`; writes the plugin's `catalogs/manifest.json`, `catalogs/en.json` and `config/locales/fomio_app.<locale>.yml`; removes retired overlay files. Refuses a translation file that holds mapped or unknown keys, and any YAML that does not round-trip.
- `Localization/manifest.json`: source schema 3. Each Fomio entry gains `site_text_key`; `terminology` gains `setting` and `keys` (51 "discussion" keys, 75 "community" keys, 117 distinct); rules rewritten for site texts.
- `Localization/fixtures/*`: regenerated with the new builder. Every message, fallback list and plural category is identical to the schema-2 fixtures; only `coverage` gains `override`, `outdated_override` and `terminology`, so revisions change.
- Docs: design, contract, strategy, development guide, docs map, acceptance, API reference.

**Plugin (`fomio/app-locale-catalog`, worktree `/Volumes/Develop/Projects/Dicourse-worktrees/fomio-app-locales`, base `01e457a9275`, Discourse `d4296c5ecf2`)**

- v0.3.0. Fomio keys are Discourse translation keys `fomio_app.<key, "." written "__">` in `config/locales/fomio_app.{en,ar}.yml`. The key is flat because 17 app keys are prefixes of other keys (for example `auth.sign_out` and `auth.sign_out.confirm_title`), which nested YAML cannot hold.
- `catalogs/ar.json` (overlay) removed.
- `CatalogBuilder`: per key, the locale's own override, then its own translation (Discourse client translation, or the plugin's YAML read directly, without Discourse's locale fallback), then English as served. Plural overrides merged per category over the locale's own forms (also for mapped keys, which v0.2.0 did not do). `deprecated` overrides ignored; `outdated` served and counted. Terminology gate: setting `fomio_app_terminology_overrides`, default off.
- `coverage` adds `override`, `outdated_override`, `terminology: {enabled, discussion: {total, overridden}, community: {…}}`. The wire schema stays 2.
- README, `script/export_catalogs.rb` (reports `site_texts` instead of `overlay`).

## Settled during implementation

| Design item | Implementation |
| --- | --- |
| Namespace `fomio_app.*` in a server file | File `config/locales/fomio_app.<locale>.yml`. Discourse loads plugin locale files by the `.<locale>.yml` suffix (`lib/freedom_patches/translate_accelerator.rb:53`), so `pt_BR` never loads `pt`. Not in any web JavaScript bundle (`JsLocaleHelper` reads only `client*.yml`). |
| No-fallback lookup | The builder reads its own YAML file per locale instead of calling `I18n.t`, so neither locale fallback nor Discourse's own override layer is mixed in. |
| Wire schema | Stays 2; app builds decode the new coverage fields as unknown and ignore them (unit tests below). |

## Evidence

| Check | Result |
| --- | --- |
| Baseline before changes | `LOAD_PLUGINS=1 bin/rspec plugins/discourse-fomio-app-locales/spec`: 44 examples, 0 failures |
| Plugin specs after | 57 examples, 0 failures ([log](plugin-rspec.log)) |
| Mutation checks | Gate disabled → 1 failure (terminology spec). Plural overrides ignored → 3 failures (two builder specs, one admin request spec). Builder restored byte-identical afterwards. |
| Lint | `bundle exec rubocop plugins/discourse-fomio-app-locales`: no offenses; the pre-commit hook's `stree check` (repository `.streerc`): clean after reformatting |
| Generator | `site-texts.rb check`: in sync, 5 files ([output](generator-check.txt)); JSON output byte-identical to the existing one-space format before any field changed |
| Coverage, all 49 Discourse locales | `discourse`, `overlay`, `english_fallback` counts identical to the schema-2 report for every locale ([report](coverage-49-locales-v030.json)) |
| Fixture messages | en, ar, he, ru, pt_BR, ja: messages, `fallback`, `plural_categories`, `direction` identical to schema 2 |
| App unit tests (`FomioTests`, iPhone 17 simulator, iOS 26.0) | 128 tests, 0 failures, 4 skipped (the opt-in live Discourse tests, which need `FOMIO_LIVE_READ_TESTS`/`FOMIO_LIVE_WRITE_TESTS`). Includes the localization and coverage tests that decode the regenerated fixtures, so current app code accepts the new coverage fields ([log](app-unit-tests.log.gz)). UI tests not run. |

### Admin editor (request spec, local Discourse `d4296c5`)

`spec/requests/site_texts_spec.rb`, signed in as an administrator, through the real `Admin::SiteTextsController`:

- `GET /admin/customize/site_texts.json?q=fomio_app.auth__signed_in` lists the key with `interpolation_keys: ["name"]`; with `locale=ar` it shows a value other than the English text (the plugin's Arabic).
- A plural Fomio key is listed per Russian category (`.one`, `.few`, `.many`, `.other`).
- `PUT /admin/customize/site_texts/fomio_app.auth__signed_in.json` saves an override that the app catalog then serves.
- An override with an unknown `%{…}` key is refused with 422 and the catalog keeps the English text.
- Per-category plural overrides saved for Russian (no plugin file) are served together.

These cover the three points the [live listing check](../../localization-site-text-design.md#source-evidence-d4296c5) left open: saving a plugin-key override, plural keys, and the `fomio_app.*` namespace. They ran against the local reference revision, not the deployed `821e9e2f`. `git diff d4296c5ecf2 821e9e2f9f94` is empty for `app/controllers/admin/site_texts_controller.rb`, `app/models/translation_override.rb`, `lib/i18n/backend/discourse_i18n.rb` and `lib/freedom_patches/translate_accelerator.rb`, so the same behavior is expected there; it is not verified on the live site.

## Not done

- Wider Discourse key mapping (design step 4): no new mappings; still 49.
- Push of the app branch or the backend branch (only the standalone plugin repository was pushed).

## Commits

- Plugin: `32d78e57942` on `fomio/app-locale-catalog` (parent `01e457a9275`). The new plugin files were force-added, since Discourse's `.gitignore` excludes `/plugins/*`. Discourse's pre-commit hook (i18n-lint, yaml-syntax, syntax_tree with the repository's `.streerc`, rubocop) passed; it reformatted two lines to the 100-column setting, after which the plugin specs were rerun: 57 examples, 0 failures.
- App: this branch, the commit that adds this record.

## Deployment and live verification

| Step | Status / evidence |
| --- | --- |
| Release commit | `git subtree split` produced `d3391cc`, which is **not** a descendant of the published `main` (`07bb7d3`): the split rebuilt earlier commits with different IDs. Instead, `171fa30465cda55bbbc24c140e884c811aa91f12` was created with `git commit-tree`: tree of `32d78e57942:plugins/discourse-fomio-app-locales` (checked identical), parent `07bb7d3`. 15 files changed against `07bb7d3`; secret scan of the diff: no matches other than two manifest notes naming Discourse keys (`js.user_api_key…`, "auth token details") |
| Publish (owner-authorized) | `git push --atomic … 171fa30:refs/heads/main 171fa30:refs/tags/v0.3.0`, no force. Remote: `main` and `v0.3.0` → `171fa30`; `v0.1.0` → `52cbcad` and `v0.1.1` → `07bb7d3` unchanged. Anonymous `git clone --branch v0.3.0 --depth 1` → `171fa30`, `diff -r` identical to the plugin directory |
| Released app builds | `main` and `27db168` (0.9.0 (8)) contain no `Localization/` code and no `app-locales` request, so the retired schema-1 routes affect only unmerged branch builds, which request schema 2 |
| Host installation | Done by the project owner in the droplet console with [operator-v0.3.0.md](operator-v0.3.0.md) (the agent did not drive the console): one clone line `v0.1.1` → `v0.3.0`, rebuild exit 0, `/srv/status` ok. Discourse is unpinned and moved from `821e9e2f9f94` to `02e1115201f01cf33427b1adec96674e8010bb2b` |
| Anonymous ([log](verify-v030-anonymous.txt), [script](verify-live-catalogs.sh)) | **All pass.** Index lists `en` only. `en` 200, 482 messages, revision `4bb2ee82cea51f43` (**identical to the local builder's fixture revision**, so the live output is byte-for-byte the tested one), `fallback` empty, `override` 0, terminology `enabled: false`. Public 5-minute caching; no `X-Discourse-Username`. Conditional 304 uncompressed; gzip `W/"4bb2ee82cea51f43"` → 304; index (not compressed in transit) → 304. 404: `/2/xx`, `/2/AR`, `/2/ar` (not allowlisted), `/3/index`, and the retired `/1/index`, `/1/en`. Live English messages equal the app's bundled English (0 differing keys) |
| Signed in ([result](verify-v030-signed-in.json), [script](verify-member-session.js)) | Admin session (v0.1.1 was checked with a moderator). Index and `en` 200, bodies identical to anonymous, no username in headers or bodies, 404s correct. **Difference from v0.1.1:** signed-in responses carry `Cache-Control: no-store, must-revalidate, private, max-age=0` and no ETag, so no 304. The same session gets the same header on `/latest.json` and `/site/basic-info.json`, which the plugin does not serve, so this is Discourse's handling of this signed-in admin session at `02e1115201f`, not the plugin. Not investigated further: `02e1115201f` is not in the local checkout. The app's catalog requests carry no cookies and get public caching and 304 (same session, credentials omitted: `max-age=300, public`, `W/"4bb2ee82cea51f43"`) |
| Admin editor ([result](verify-v030-admin-editor.json)) | Read-only GETs, nothing saved. Settings: `fomio_app_locales_enabled` true, `fomio_app_locales` `en`, `fomio_app_terminology_overrides` false. Search `fomio_app.` returns Fomio keys in pages of 50 (en and ar). `fomio_app.auth__signed_in`: en "Signed in as %{name}.", ar the plugin's Arabic, `interpolation_keys` `["name"]`. `fomio_app.post__like_count` in Russian is listed per category (`one`, `few`, `many`, `other`). Saving an override: see [follow-up checks](#follow-up-checks-2026-10-22) |

## Follow-up checks (2026-10-22)

| Check | Result |
| --- | --- |
| Live save through the admin editor ([result](verify-v030-live-edit.json)) | Signed-in admin session, the editor's own endpoints. Key `fomio_app.auth__signed_in`, locale `ru`: not offered to the app and never shown by the Discourse web UI, so no member saw it. No `ru` override existed before. `%{someone}` → **422** ("The following interpolation key is invalid: someone"), nothing stored. Valid value → **200**, read back as overridden. Revert (`DELETE ?locale=ru`) → **200**, no override left. Live `en` ETag unchanged (`4bb2ee82cea51f43`). Side effect: two staff action log entries (save, revert). The catalog's use of an override was verified by local specs only, because `ru` is not allowlisted live |
| Live app UI tests, iPhone 17 (iOS 26.0) ([log](live-ui-iphone.log.gz)) | `LiveLocalizationUITests` against v0.3.0: **3/3 pass** (Arabic iOS fresh install → English, Me › Language lists only English from the live index, relaunch with catalog offline keeps English; English iOS without cache → bundled English; Back/edge-swipe anchors and Cards persistence) |
| Live app UI tests, iPad Pro 11-inch (M5), iOS 27.0 ([log](live-ui-ipad27.log.gz)) | Both localization tests **pass**. `testLiveBackSwipeAnchorsAndFeedAppearancePersistence` **fails**: after tapping Back the topic row is 8 pt from its earlier position (tolerance 4 pt), line 102. Not related to the catalog. A rerun of that test alone did not run: the UI test runner crashed while bootstrapping (`signal abrt while preparing to run tests`) ([log](live-ui-ipad27-rerun.log.gz)). Open: whether the 8 pt offset is a regression against live content or a flaky measurement. Resolved below: a measurement taken before communities loaded |
| Live app UI tests, iPad Pro 11-inch (M5), iOS 26.0 ([log](live-ui-ipad.log.gz)) | 1/3 pass. The Arabic fresh-install test cannot find the `me-language` button after opening Me (passes on iOS 27.0), and the Back-swipe test fails at line 115 (`XCTAssertTrue`). The deployment target is iOS 26.0, so this is a supported configuration. Not related to the catalog; open for investigation. Earlier iPad passes were on iOS 27 simulators. Resolved below |
| iPad failures diagnosed (both iPad runtimes) | All three are intermittent, not app regressions; the unchanged tests then passed **3/3** on iOS 26.0 twice ([log](live-ui-rerun26a.log.gz), [log](live-ui-rerun26b.log.gz)) and on iOS 27.0 once ([log](live-ui-rerun27.log.gz)). Evidence from the failing runs' screen recordings, synthesized-event records and simulator log. **iOS 27.0, 8 pt after Back (test assumption):** the anchor was read before communities had loaded; the pinned row then gained its "General" community line, which moved the row's button frame by 8 pt. The scroll position itself was identical before and after Back (heading and guest note unmoved). **iOS 26.0, `me-language` not found (platform tap race):** the tap landed at the centre of Me (617.5, 54); the recording shows Me selected for a moment and the selection lens returning to Home. Nothing in the app writes `selectedTab` outside the composer and development presets, and the API and catalog requests had finished about 5 s earlier (only feed images were loading). **iOS 26.0, line 115 (platform tap race):** the tap on the open options menu landed inside Cards (700, 97 in 588–812 × 78–116); the menu stayed open and nothing was chosen. Neither tap loss has been reproduced since; they are recorded as iOS 26.0 Liquid Glass tap losses under XCUITest, not as user-facing defects. Possible content shift while communities load after the feed is a separate design question, not tested here |
| Live app UI tests after test fixes ([test](../../../FomioUITests/LiveLocalizationUITests.swift)) | Anchor read only after a `topic-category-*` button exists; tabs tapped until selected and appearances chosen until the feed changes (up to 3 attempts each). **3/3 pass** on iPhone 17 iOS 26.0 ([log](live-ui-fixphone.log.gz)), iPad Pro 11-inch (M5) iOS 26.0 twice ([log](live-ui-fix26.log.gz), [log](live-ui-fix26b.log.gz)) and iOS 27.0 twice ([log](live-ui-fix27.log.gz), [log](live-ui-fix27b.log.gz)). No retry fired in these runs (one tap each on Me, Cards and Compact), so the retry paths are untested against a real tap loss |
| Plugin specs at deployed `02e1115201f` ([log](plugin-rspec-02e1115.log)) | **57 examples, 0 failures.** Worktree `/Volumes/Develop/Projects/Dicourse-worktrees/deployed-02e1115` (detached at `02e1115201f`; gems in its `vendor/bundle`; `pnpm install --frozen-lockfile` with pnpm 12.11.2, 1,612 packages ([log](pnpm-02e1115.log.gz)); database `discourse_test_fomio_02e1115` migrated ([log](db-02e1115.log.gz)); plugin from `32d78e57942`, identical to the published `v0.3.0`; `fomio_plgin` `1cd3462` as in production). First attempt was blocked: the locally switched pnpm 12.11.2 was broken (`ENOEXEC`: pnpm's self-switch had left the shebang-less placeholder that its install script normally replaces with the native binary). With the owner's approval it was reinstalled with `npm install pnpm@12.11.2` (native `@pnpm/exe.darwin-arm64`) into `~/Library/pnpm/.tools/pnpm/12.11.2`; the broken copy was moved aside, not deleted. Source comparison (`git diff d4296c5ecf2 02e1115201f`): the site-text files (`app/controllers/admin/site_texts_controller.rb`, `app/models/translation_override.rb`, `lib/i18n/backend/discourse_i18n.rb`, `lib/freedom_patches/translate_accelerator.rb`, `app/models/locale_site_setting.rb`) are unchanged; `lib/js_locale_helper.rb` changes only moment.js locale paths and `lib/plugin/instance.rb` only `register_homepage` |
