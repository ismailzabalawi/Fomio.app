# Interface catalog contract and backend handoff

Status, 2026-10-15: **proposed contract; not implemented or deployed on any Discourse backend.** The iOS client implements and tests this contract against sanitized fixtures and a scripted transport. No backend file was changed. Building the endpoint requires a separately authorized task against `/Volumes/Develop/Projects/Dicourse` and a deployment.

## Deployed-site check (2026-10-15, read-only, anonymous)

| Check | Result |
| --- | --- |
| Deployed revision | `<meta name="generator">` = Discourse 2026.8.0-latest, commit `7b4f0970506fb0ce7d4b6a851d252ace418330c8` (unchanged since 2026-10-04). Local reference HEAD still `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. |
| Locale settings (public preloaded client settings on `/latest`) | `default_locale` en; `allow_user_locale` false; `set_locale_from_accept_language_header`, `set_locale_from_cookie`, `set_locale_from_param` false; `content_localization_supported_locales` empty; `ai_translation_enabled` false; `support_mixed_text_direction` false; `login_required` false. `available_locales` lists Discourse's full locale set (including `ar`). |
| Native catalog route | None. Public plugin assets list checklist, details, lazy-videos, local-dates, presence, reactions, solved, templates, topic-voting, poll, spoiler-alert: no localization plugin. Probes of plausible paths returned 404 (they were checks, not assumptions). |
| Overrides | `/extra-locales/<digest>/en/overrides.js` (fetched once to inspect, never executed or used by the app): English-only overrides mapping topic → Byte/Bytes, category → Hub, subcategory → Teret/terets, with inconsistent casing (`js.topic.new` = "new byte", `js.topic.create` = "New Byte") and one malformed value (`js.category.all` = literal "js.hubs.all"). |

Conclusion: the app keeps bundled English for live builds (`UnavailableLocalizationTransport`). Live verification of non-English catalogs is blocked on the endpoint below.

## Endpoints (proposed)

Paths are deliberately not hard-coded in the app. When deployed, set the app's Info values `FomioLocaleIndexPath` and `FomioLocaleCatalogPath` (placeholders `{schema}` and `{locale}`), relative to the configured base URL and relative root. Example only: `fomio/app-locales/{schema}/index.json` and `fomio/app-locales/{schema}/{locale}.json`.

Both are `GET`, public, read-only, anonymous-safe, and must behave the same under `login_required` (decide explicitly; the catalog contains no member data). No cookies, CSRF or user keys. Respond `200` with `ETag` and `Cache-Control: public, max-age=…`; honor `If-None-Match` with `304`. Unknown or disabled locale → `404`. Payload ≤ 1 MB. `Content-Type: application/json`.

### Index

```json
{"schema": 1, "default_locale": "en",
 "locales": [{"locale": "en", "name": "English", "native_name": "English", "direction": "ltr", "complete": true, "revision": "…"},
             {"locale": "ar", "name": "Arabic", "native_name": "العربية", "direction": "rtl", "complete": true, "revision": "…"}]}
```

List only locales enabled for the app. `complete` is true only when every key in the manifest resolves to a valid value for that locale.

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

## Backend work items (separately authorized task)

1. Plugin or core route + controller under the deployed version, serializer producing the schema above, `ETag`/`304`, cache headers, anonymous access policy, locale allowlist.
2. Ship the manifest and maintained catalogs with the backend integration; a reviewer process for translations (the Arabic file is agent-authored and needs native review).
3. Request specs: anonymous 200/304/404, login_required behavior, override change → new revision, missing Discourse translation → maintained fallback, markup/key-valued override rejected, payload limit.
4. Deploy, then verify anonymously and with a member account on the live site; record revision, headers and a sanitized response in `docs/discourse-api-reference.md`; set the Info paths; run the live checklist in [acceptance](localization-acceptance.md).
5. Separate operational decision: whether to enable `allow_user_locale` so server-generated text (validation errors, emails) follows the member's language. Interface catalogs do not require it, and content translation stays off.
