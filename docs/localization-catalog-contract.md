# Interface catalog contract and backend handoff

Proposal, 2026-10-21: [interface strings as Discourse site texts](localization-site-text-design.md) (source schema 3; wire schema stays 2). Not implemented.

Status, 2026-10-18: **schema 2 (Discourse translation reuse, sparse Fomio overlays, English fallback) is implemented locally in plugin v0.2.0 and the app; it is not published or deployed.** The live site still runs v0.1.1 (schema 1, `07bb7d3`, deployed 2026-10-17 on Discourse `821e9e2f`). An app build with this change requests schema 2, so against the current site it gets 404 and offers English only, until v0.2.0 is deployed (separate authorization). History of the schema-1 deployment: [deployment record](validation/2026-10-16-live-deployment/README.md). Schema-2 evidence: [validation record](validation/2026-10-18-sparse-catalogs/README.md).

## Deployed-site check (2026-10-15, read-only, anonymous)

| Check | Result |
| --- | --- |
| Deployed revision | `<meta name="generator">` = Discourse 2026.8.0-latest, commit `7b4f0970506fb0ce7d4b6a851d252ace418330c8` (unchanged since 2026-10-04). Local reference HEAD still `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. |
| Locale settings (public preloaded client settings on `/latest`) | `default_locale` en; `allow_user_locale` false; `set_locale_from_accept_language_header`, `set_locale_from_cookie`, `set_locale_from_param` false; `content_localization_supported_locales` empty; `ai_translation_enabled` false; `support_mixed_text_direction` false; `login_required` false. `available_locales` lists Discourse's full locale set (including `ar`). |
| Native catalog route | None. Public plugin assets list checklist, details, lazy-videos, local-dates, presence, reactions, solved, templates, topic-voting, poll, spoiler-alert: no localization plugin. Probes of plausible paths returned 404 (they were checks, not assumptions). |
| Overrides | `/extra-locales/<digest>/en/overrides.js` (fetched once to inspect, never executed or used by the app): English-only overrides mapping topic → Byte/Bytes, category → Hub, subcategory → Teret/terets, with inconsistent casing (`js.topic.new` = "new byte", `js.topic.create` = "New Byte") and one malformed value (`js.category.all` = literal "js.hubs.all"). |

Conclusion: live builds use `DiscourseLocalizationTransport` with the configured paths below. The live site offers English only (`fomio_app_locales` = `en`), so the app lists English and shows the live English catalog (identical to bundled English). Live verification of a non-English catalog needs an approved language (E3/E4).

## Endpoints (schema 2)

The app's Info values `FomioLocaleIndexPath` = `fomio/app-locales/{schema}/index.json` and `FomioLocaleCatalogPath` = `fomio/app-locales/{schema}/{locale}.json` (relative to the configured base URL and relative root); `{schema}` is 2. Both are `GET`, public, read-only and anonymous (also under `login_required`); signed-in requests get the same body and no `X-Discourse-Username`. `ETag` = revision; `If-None-Match` uses weak comparison (304 for `W/"…"`, lists and `*`); `Cache-Control: public, max-age=300`. 404 for another schema, a locale outside the allowlist, a locale without Discourse plural rules, a malformed code or a disabled plugin. Payload ≤ 1 MB.

### Index

```json
{"schema": 2, "default_locale": "en",
 "locales": [{"locale": "he", "name": "Hebrew", "native_name": "עברית", "direction": "rtl", "complete": true,
              "plural_categories": ["one", "two", "many", "other"],
              "coverage": {"total": 482, "discourse": 49, "overlay": 0, "english_fallback": 433}, "revision": "…"}]}
```

Only locales in the plugin's own allowlist `fomio_app_locales` (default `en`; separate from Discourse's web interface languages, `allow_user_locale` and content translation) that Discourse supports and has plural rules for. No language is ever enabled automatically, and `default_locale` is always `en` (the app ignores it). The app lists an entry only if it is complete, its direction is `ltr`/`rtl` and `plural_categories` equal the app's own rules for that locale; otherwise the language is explicitly unsupported and not shown. `coverage.english_fallback > 0` makes Me › Language say “Partly translated: some text appears in English”.

### Catalog

```json
{"schema": 2, "locale": "he", "revision": "content-digest", "direction": "rtl", "complete": true,
 "plural_categories": ["one", "two", "many", "other"],
 "fallback": ["tab.communities", "…"],
 "coverage": {"total": 482, "discourse": 49, "overlay": 0, "english_fallback": 433},
 "messages": {"tab.home": "בית", "tab.communities": "Communities",
              "discussion.replies": {"one": "תגובה", "two": "שתי תגובות", "other": "{count} תגובות"},
              "post.like_count": {"one": "Like {count}", "other": "Like {count}"}}}
```

Every manifest key is present (assembled, complete). `fallback` lists the keys whose value is English.

## Resolution rules (`Localization/manifest.json`, schema 2)

- 482 keys: **49** map to a semantically equivalent Discourse client key (`source: discourse`), each with a recorded review (`verified`); 433 are Fomio-specific (`source: fomio`). Reviewed-and-rejected candidates are listed with reasons in `rejected_candidates` (equal wording alone is never enough).
- English: the app's bundled English; a valid `en` site-text override replaces a mapped key.
- Other locales, per key: (1) mapped key → that locale's own Discourse translation (`JsLocaleHelper.translations_for(locale, no_fallback: true)`; a regional locale such as `pt_BR` never borrows `pt`), with that locale's override first when valid; (2) Fomio key → the sparse overlay `Localization/catalogs/<locale>.json` (Fomio keys only; Arabic is the only overlay today); (3) otherwise English as served, listed in `fallback`. A missing or invalid translation never makes a catalog incomplete.
- Convert `%{name}` to `{name}`, renaming per the entry's `placeholders` map (for example `levelNumber` → `level`). Never emit markup or keys as values; never apply one locale's override to another.
- Plural categories are Discourse's CLDR keys for the locale (`I18n.t("i18n.plural.keys")`, config/locales/plurals.rb). A translated plural must contain `other` (with `{count}` when English uses it) and only those categories; a form it omits (for example Hebrew `many`) is shown as `other`, as Discourse does. A fallback plural keeps English forms and is selected with English rules.
- Topic/category nouns are not mapped (terminology decision in the manifest and [strategy](localization-strategy.md#terminology-and-override-policy)).

## Client validation and rendering (`Fomio/Localization`)

`CatalogValidator` accepts a catalog only if: schema is 2; `complete` is true; the locale is the requested one (same language); direction is `ltr`/`rtl`; `plural_categories` equal the app's rules for the locale (`PluralRules`: all 15 integer families of Discourse's 49 client locales, checked against a table computed from Discourse's own rules, `Localization/discourse-plural-truth.json`); every bundled English key is present with the same kind; text placeholders match English; plural forms are within the locale's categories (English categories for `fallback` keys), include `other` with `{count}` when English uses it, keep non-count placeholders and use no others; no value is blank, too long (1,200), markup, `%{…}`/printf, unbalanced braces or a raw key. Unknown extra keys are ignored.

Rendering (`Localizer`): a fallback message uses English plural rules and English digits, isolates its arguments left to right and, inside a right-to-left catalog, is wrapped as one left-to-right isolate (U+2066…U+2069). A localized fragment inserted into another message (a compact age in “Active {age} ago”, a style name in “Turn into {style}”) names its container (`within:`) and is English whenever the container is, so one sentence never mixes languages; shown on its own, the fragment keeps its translation.

## Backend implementation history (v0.1.0 deployed 2026-10-16, v0.1.1 deployed 2026-10-17; v0.2.0 local only, 2026-10-18)

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

### Plugin v0.2.0 (schema 2), local only

| Item | Status |
| --- | --- |
| `CatalogBuilder` assembles Discourse translation → overlay → English per key; `fallback`, `coverage`; Discourse plural keys; placeholder renames; same-locale overrides; regional locales stay separate | Implemented, backend branch `fomio/app-locale-catalog` (not pushed) |
| Index adds `plural_categories` and `coverage`; any allowlisted Discourse locale with plural rules is offered (allowlist default still `en`) | Implemented |
| Specs (`LOAD_PLUGINS=1 bin/rspec plugins/discourse-fomio-app-locales/spec`) at Discourse `d4296c5`: 44 examples, 0 failures; RuboCop and syntax_tree clean | 2026-10-18 |
| `script/export_catalogs.rb`: coverage report for all 49 locales and the app's Debug fixtures, using the real builder without writing settings | Implemented |
| Specs at deployed `821e9e2f` | Not run (pnpm 12 tooling, as for v0.1.1); mapped Discourse values compared directly between `d4296c5` and `821e9e2f` for all 49 locales: only Lithuanian differs (7 values) |
| Publication (v0.2.0 tag) and deployment | **Not done**; not authorized in this task |

