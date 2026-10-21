# Interface strings as Discourse site texts: plugin v0.3.0 (local)

Date: 2026-10-21. Design: [localization-site-text-design.md](../../localization-site-text-design.md). Authorized by the project owner as local backend work only: no push, no publication, no deployment, no live setting or site text changed.

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
- Publication (v0.3.0 tag in the standalone repository), deployment, and live verification on meta.fomio.app.
- Specs at the deployed revision `821e9e2f`.
- Push of either branch.

## Commits (local, not pushed)

- Plugin: `32d78e57942` on `fomio/app-locale-catalog` (parent `01e457a9275`). The new plugin files were force-added, since Discourse's `.gitignore` excludes `/plugins/*`. Discourse's pre-commit hook (i18n-lint, yaml-syntax, syntax_tree with the repository's `.streerc`, rubocop) passed; it reformatted two lines to the 100-column setting, after which the plugin specs were rerun: 57 examples, 0 failures.
- App: this branch, the commit that adds this record.
