# Interface catalog contract and backend handoff

Status, 2026-10-17: **deployed on meta.fomio.app as plugin `discourse-fomio-app-locales` v0.1.1** (`07bb7d38065ede03d0ac9f49f4f89d9ae8d4eed3`, https://github.com/ismailzabalawi/discourse-fomio-app-locales) on Discourse `821e9e2f9f94483a3be8d1e077cde0fd94970479`, verified anonymously and signed in, including compressed 304s. Source: backend branch `fomio/app-locale-catalog` (`e3fd4b3647f`, not pushed). History and evidence: [deployment record](validation/2026-10-16-live-deployment/README.md).

## Deployed-site check (2026-10-15, read-only, anonymous)

| Check | Result |
| --- | --- |
| Deployed revision | `<meta name="generator">` = Discourse 2026.8.0-latest, commit `7b4f0970506fb0ce7d4b6a851d252ace418330c8` (unchanged since 2026-10-04). Local reference HEAD still `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. |
| Locale settings (public preloaded client settings on `/latest`) | `default_locale` en; `allow_user_locale` false; `set_locale_from_accept_language_header`, `set_locale_from_cookie`, `set_locale_from_param` false; `content_localization_supported_locales` empty; `ai_translation_enabled` false; `support_mixed_text_direction` false; `login_required` false. `available_locales` lists Discourse's full locale set (including `ar`). |
| Native catalog route | None. Public plugin assets list checklist, details, lazy-videos, local-dates, presence, reactions, solved, templates, topic-voting, poll, spoiler-alert: no localization plugin. Probes of plausible paths returned 404 (they were checks, not assumptions). |
| Overrides | `/extra-locales/<digest>/en/overrides.js` (fetched once to inspect, never executed or used by the app): English-only overrides mapping topic → Byte/Bytes, category → Hub, subcategory → Teret/terets, with inconsistent casing (`js.topic.new` = "new byte", `js.topic.create` = "New Byte") and one malformed value (`js.category.all` = literal "js.hubs.all"). |

Conclusion: live builds use `DiscourseLocalizationTransport` with the configured paths below. The live site offers English only (`fomio_app_locales` = `en`), so the app lists English and shows the live English catalog (identical to bundled English). Live verification of a non-English catalog needs an approved language (E3/E4).

## Endpoints

The app's Info values `FomioLocaleIndexPath` = `fomio/app-locales/{schema}/index.json` and `FomioLocaleCatalogPath` = `fomio/app-locales/{schema}/{locale}.json` (relative to the configured base URL and relative root) match the plugin's routes.

Both are `GET`, public, read-only and anonymous, also under `login_required` (decided: the catalog contains no member data; the controller skips the login/profile redirects like `ExtraLocalesController`). Signed-in requests get the same body, and `X-Discourse-Username` is removed (see below). No cookies, CSRF or user keys. Respond `200` with `ETag` and `Cache-Control: public, max-age=…`; honor `If-None-Match` with `304`. Unknown or disabled locale → `404`. Payload ≤ 1 MB. `Content-Type: application/json`.

### Index

```json
{"schema": 1, "default_locale": "en",
 "locales": [{"locale": "en", "name": "English", "native_name": "English", "direction": "ltr", "complete": true, "revision": "…"},
             {"locale": "ar", "name": "Arabic", "native_name": "العربية", "direction": "rtl", "complete": true, "revision": "…"}]}
```

List only locales enabled for the app: the plugin's own `fomio_app_locales` allowlist (default `en`; separate from Discourse's web `available_locales`/`allow_user_locale` and from content translation) ∩ Discourse-supported locales ∩ languages with app plural rules ∩ catalogs that pass validation. `complete` is always true for listed entries. `default_locale` is always `en`, and the app ignores it.

### Catalog

```json
{"schema": 1, "locale": "ar", "revision": "content-digest", "direction": "rtl", "complete": true,
 "plural_categories": ["zero", "one", "two", "few", "many", "other"],
 "messages": {"tab.home": "الصفحة الرئيسية",
              "discussion.replies": {"zero": "…", "one": "…", "two": "…", "few": "{count} ردود", "many": "{count} ردًا", "other": "{count} رد"}}}
```

`revision` changes whenever any resolved value changes (including a site-text override edit); the `ETag` may equal it. The examples are fixtures, not live responses.

## Resolution rules (from `Localization/manifest.json`)

- 481 keys. 35 reuse an exact Discourse key (`source: discourse`): resolve `I18n.t(discourse_key, locale:)` including that locale's site-text override. If the locale has no translation of its own (Discourse would fall back to English) or the resolved value fails validation, use the maintained Fomio value for that locale. Every mapped key was checked to exist with the same English value at the deployed and local revisions.
- 446 keys are Fomio-only (`source: fomio`): serve `Localization/catalogs/<locale>.json` (English: `Fomio/Resources/Localization/fomio-catalog-en.json`).
- Convert Discourse `%{name}` to `{name}`. Never emit markup, Discourse keys as values, or user-specific text. Never apply one locale's override to another locale.
- Topic/category nouns are not mapped (see the terminology decision in the manifest and [strategy](localization-strategy.md#terminology-and-override-policy)).

## Client validation (what the backend must satisfy)

`Fomio/Localization/LocalizationCatalog.swift` (`CatalogValidator`) accepts a catalog only if: schema is 1; `complete` is true; the resolved locale has the requested language; direction is `ltr`/`rtl`; the app has CLDR plural rules for it and `plural_categories` match them; every key in the bundled English catalog is present with the same kind (text vs plural); text placeholders match exactly; plural messages carry every category, use only allowed placeholders, keep non-count placeholders in every form and show `{count}` in `other`; no value is blank, too long (1,200 characters), markup, `%{…}`/`%@` formatting, unbalanced braces or a raw key. Unknown extra keys are ignored. Languages currently supported by app plural rules: English, Arabic, and one-form languages (ja/ko/zh). Add others in the app with tests before enabling them.

## Backend implementation (2026-10-15; v0.1.0 deployed 2026-10-16, v0.1.1 deployed 2026-10-17)

| Item | Status |
| --- | --- |
| Plugin `discourse-fomio-app-locales`: Rails engine at `/fomio/app-locales`, `CatalogsController#index/#show`, `CatalogBuilder` | Implemented |
| Resolution: the locale's own client translation (`JsLocaleHelper.translations_for(locale, no_fallback: true)`) and that locale's `TranslationOverride.client_locales` override; failures fall back to the maintained value | Implemented, request specs |
| `CatalogBuilder::Validator` mirrors `CatalogValidator` for the maintained catalog *and* every served message: kind, plural forms, placeholders, control characters, markup, `%{}`/printf, raw keys, braces, length, message count, 1 MB payload | Implemented; 30 mutation examples (21 message, 5 metadata, oversized catalog, oversized payload, English reference missing a key, plural dropping a non-count placeholder) |
| ETag = revision, 304, `Cache-Control: public, max-age=300`; 404 for other schemas, disallowed, unsupported, invalid or malformed locales, and when the plugin is disabled | Request specs |
| Allowlist default `en`; Arabic is review-required before it is added | Setting default + spec; README |
| `X-Discourse-Username` stripped from 200/304 (7b4f0970's `set_current_user_for_logs` sets it on every signed-in response; d4296c5 only on private ones, commit 6735ce7e2b7; nginx sample hides it only for asset paths) | Request specs simulate the deployed callback; verified failing without the fix |
| Catalog sync from the app (manifest, en, ar) | Manual copy; procedure in plugin README |
| Specs: `LOAD_PLUGINS=1 bin/rspec plugins/discourse-fomio-app-locales/spec` → 46 examples, 0 failures; RuboCop and syntax_tree clean | 2026-10-15 |
| Deployment (standalone repo `ismailzabalawi/discourse-fomio-app-locales`, `app.yml` clone, rebuild), then anonymous and member verification on the live site | **v0.1.1 deployed 2026-10-17** on Discourse `821e9e2f9f94`; verified anonymously and signed in, including compressed 304s ([record](validation/2026-10-16-live-deployment/README.md)) |

Separate operational decision, unchanged: whether to enable `allow_user_locale` so server-generated text (validation errors, emails) follows the member's language. Interface catalogs do not require it, and content translation stays off.
