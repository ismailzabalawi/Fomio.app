# Interface strings as Discourse site texts (source schema 3)

Status, 2026-10-21: **design proposal only.** No backend file, plugin, setting or site text was changed, and nothing was deployed. Backend findings below come from the local reference checkout `/Volumes/Develop/Projects/Dicourse` at `d4296c5ecf2` and the local plugin branch `fomio/app-locale-catalog` (v0.2.0, not pushed). None of them are verified on the deployed site. Implementation needs a task that authorizes backend work ([AGENTS.md](../AGENTS.md)).

This builds on the [catalog contract](localization-catalog-contract.md) (schema 2) and the [strategy](localization-strategy.md). It does not replace the app-side validator, the allowlist or the bundled English fallback.

## Why change schema 2

Schema 2 already reuses Discourse site text, but only for part of the interface:

- **49 of 482 keys** map to a Discourse client key. Only those 49 pick up the locale's Discourse translation and that locale's admin override (Admin → Customize → Text).
- **433 Fomio-only keys** live in the app repository (`Fomio/Resources/Localization/fomio-catalog-en.json`, `Localization/catalogs/<locale>.json`) and are copied into the plugin by hand. An admin cannot see or change them, and a wording fix needs a plugin release.
- **Terminology is fixed.** The forum's English web overrides (topic → Byte, category → Hub, subcategory → Teret) are deliberately not mapped, because single-word substitution would mix "Byte" with Fomio sentences that say "discussion" ([policy](localization-strategy.md#terminology-and-override-policy)).

## Goals and non-goals

Goals:

1. Every app interface string is a Discourse translation key that an administrator can find and override in Admin → Customize → Text, per locale, with Discourse's own placeholder checks and stale-override tracking.
2. Forum terminology (Byte, Hub, or anything else) can reach the app without an app release, by overriding **whole sentences**, never by word substitution.
3. More keys reuse Discourse's existing community translations, with the same per-key review as today.

Non-goals: changing Apple-provided UI strings, translating server-generated text (that still depends on `allow_user_locale`), enabling languages automatically, or removing bundled English.

## 1. Fomio keys become plugin translation keys

The plugin ships the 433 Fomio-only keys (and English values for all 482 keys) as its own locale files. The catalog builder resolves them through Discourse I18n and `TranslationOverride`, the same way it already resolves the 49 mapped keys.

### Source evidence (`d4296c5`)

| Need | Evidence | Finding |
| --- | --- | --- |
| Plugin locale files load into server I18n | `config/application.rb:146` adds `plugins/*/config/locales/*.yml` to `config.i18n.load_path` | Server-side `I18n.t` and `I18n.search` see plugin keys, client and server files alike. |
| Plugin client keys reach the web bundle | `lib/js_locale_helper.rb` (`plugin_client_files`, `load_translations`) deep-merges plugin `js.*`/`admin_js.*` into each locale's main bundle | A `client.*.yml` key would be shipped to **every web visitor's** JavaScript bundle. |
| Admin text search lists a key | `Admin::SiteTextsController#find_translations` searches `I18n.search` results and skips any key without `I18n.exists?(key, :en)` | The plugin must ship English for every key. Plural keys are listed per category (`key.one`, `key.other`, and the locale's other CLDR categories through `fix_plural_keys`). |
| Override placeholders are checked | `TranslationOverride#check_interpolation_keys` compares `%{…}` keys with the English original (`transform_pluralized_key` maps `zero/two/few/many` to English `other`) | Plugin values must use Discourse's `%{name}` syntax. The builder keeps converting to the app's `{name}`. |
| Overrides are sanitized, not plain text | `TranslationOverride.upsert!` runs `sanitize_field` (Rails `SafeListSanitizer`) | Safe HTML can still be stored. The plugin validator must keep rejecting markup and fall back. |
| Stale overrides are tracked | `TranslationOverride#refresh_status` on update and `Jobs::CheckTranslationOverrides` (daily) set `outdated`, `invalid_interpolation_keys` or `deprecated` | When Fomio changes an English sentence, Discourse flags the overrides built on the old wording. |
| Override edits reach the catalog | `upsert!`/`revert!` call `i18n_changed` → `I18n.reload!`; v0.2.0 `CatalogBuilder` digests the assembled body into `revision` (`catalog_builder.rb:148`) | An override changes the ETag. The app sees it at its next refresh (launch or foreground once its copy is 24 hours old). |
| Who can edit | Admin site-text routes are under the admin constraint (`config/routes.rb`; `Admin::AdminController`) | Administrators only. No member key is involved. |

**Verified live, 2026-10-21 (read-only, signed-in admin browser session on meta.fomio.app, plugin v0.1.1):** Admin → Customize → Text searched for `fomio_app_locales` lists both keys from the deployed plugin's `config/locales/server.en.yml` (`site_settings.fomio_app_locales_enabled`, `site_settings.fomio_app_locales`), each with an Edit button. With Language set to Arabic, for which the plugin has no file, the same keys are listed showing the English value, also with Edit. So an admin can add a per-locale override for a key the plugin has not translated. It also confirms that the editor displays fallback English, which is why the builder must look up a locale's own value without fallback. No text was edited. Still unverified: saving an override of a plugin key, plural plugin keys, and a `fomio_app.*` top-level namespace (the deployed keys sit under core's `site_settings.` namespace).

### Namespace: server file, not client file

Recommended: `config/locales/server.<locale>.yml` under a top-level `fomio_app.` namespace (for example `fomio_app.tab.home`).

- A `client.*.yml` (`js.fomio_app.*`) would add every app string to the web bundle downloaded by every browser visitor. The web never shows these strings.
- Server keys are still on the I18n load path, so `I18n.search` and the admin editor find them.
- `TranslationOverride.client_locales` filters to `js.%`/`admin_js.%`, so the builder queries `fomio_app.%` overrides directly (`not_deprecated`, same locale).
- Server-side I18n applies locale fallbacks. The builder must read a locale's own value **without fallback**, so that an untranslated key is reported in `fallback` instead of silently returning English (or `pt` for `pt_BR`). The exact call (`I18n.t(..., fallback: false)`, an `I18n.exists?` guard, or reading the backend's translations hash) is an implementation detail to settle with a spec.

### Source of truth and sync

The app still bundles English (offline fallback, validator reference), so English exists in two places. To remove hand copying:

- A generator in the app repository (`Localization/tools/`) emits `server.en.yml` and the manifest from `fomio-catalog-en.json`. Arabic and any reviewed overlay become `server.<locale>.yml` in the plugin.
- A check fails when the plugin's English and the app's bundled English differ (key set, kinds, placeholders, values).
- The sparse overlay files (`catalogs/<locale>.json`) are retired. The manifest keeps `source`, `discourse_key`, `placeholders`, `verified` and `rejected_candidates`. Fomio entries gain their `fomio_app.*` key.

### Translation supply

Discourse's community translation pipeline covers core and official plugins. A third-party plugin's locale files are maintained by its owner, so making Fomio keys site texts does not by itself bring in translators. What changes is **who can fix a string, and where**: a community administrator can correct a wording per locale in the admin UI, and Discourse tracks it. Non-English locales still enter the app only through the plugin allowlist `fomio_app_locales`, after review.

## 2. Resolution order

For each manifest key in locale *L* (every candidate must pass the plugin validator; an invalid candidate is skipped):

1. *L*'s own override of the key's Discourse key: `discourse_key` for a mapped key, `fomio_app.*` for a Fomio key. Not `deprecated`.
2. *L*'s own translation: Discourse's client translation for a mapped key (`JsLocaleHelper.translations_for(L, no_fallback: true)`, as today); the plugin's `server.L.yml` for a Fomio key.
3. English as served (the `en` override if valid, else plugin English), listed in `fallback`.

Unchanged rules: one locale's override never applies to another; `pt_BR` never borrows `pt`; plural categories come from `I18n.t("i18n.plural.keys")`; a missing category is shown as `other`; `%{name}` converts to `{name}` with manifest renames.

New handling for override status: `invalid_interpolation_keys` already fails validation. `outdated` overrides are served, because the admin chose them, and counted in `coverage` (below) so the operator sees them.

## 3. Terminology through sentence overrides

With every sentence a site text, branding is an editorial act in the admin UI. An administrator overrides "New discussion" with "New Byte" as one sentence, per locale. No word is substituted by code.

The risk is partial branding: today 51 English keys mention "discussion" and 75 mention "community" (6 of them "subcommunity"), with some overlap. Overriding half of them gives a mixed interface. Proposed safeguards:

- The manifest's `terminology` section lists the noun-bearing keys per noun (generated from the English catalog), replacing the current "do not map" rule.
- A plugin setting, `fomio_app_terminology_overrides` (default **off**). While it is off, overrides of noun-bearing keys are ignored and the current "discussion"/"community" wording is served. Turning it on is the operator's declaration that the set is complete.
- `coverage` gains `terminology` counts (overridden / total per noun), and the plugin README documents the admin search ("discussion", "community" filtered to `fomio_app.`) that finds every key.
- The web's existing topic/category overrides (`js.topic.*`, `js.category.*`) stay unmapped. They are web branding with known defects, and the app's noun-bearing keys are Fomio keys.

Decision for the community owner, not for this design: whether the app adopts "Byte/Hub/Teret" at all. The design makes it possible without a release; it does not make it the default.

## 4. Wider Discourse key mapping

Every Fomio key becomes overridable either way, so the only reason to map a key to a Discourse key is to **inherit Discourse's community translations** for other locales. The review rules stay strict:

- A mapping needs semantic equivalence in the app's context, not equal English wording, and a recorded review (`verified`). Rejections go to `rejected_candidates` with a reason (25 today).
- Candidate families to review next: post actions (reply, like, bookmark, share, flag), search, notifications, relative and compact dates (`js.dates.*`), user/profile labels, composer actions, and common buttons (cancel, save, delete, retry).
- `script/export_catalogs.rb` reports per-locale coverage for all 49 Discourse locales. That report, not a target key count, measures progress.
- Drift guard: before deploying on a new Discourse revision, compare mapped values between the reference and deployed revisions, as the 2026-10-18 record did (`821e9e2f` vs `d4296c5`: only Lithuanian differed, 7 values). A changed mapped value is re-reviewed.
- A mapped key whose Discourse wording an admin overrides follows that override in the app too. This is intended: one site text, both clients.

## Wire contract

The catalog and index payloads do not need to change shape: `messages`, `fallback`, `complete`, `plural_categories` and `coverage` keep their meaning. The app checks `schema == 2` and decodes `coverage` with Codable, which ignores unknown fields. So:

- **Keep wire schema 2** and add optional coverage fields (`override`, `outdated_override`, `terminology`). Current app builds keep working with no release.
- "Schema 3" is the **source** schema: manifest version and plugin locale files. Bump the wire schema only if a field's meaning changes.

## What does not change

- Apple-provided UI follows the iOS language.
- Server-generated text (validation errors, notification titles) follows `allow_user_locale`, which stays a separate operational decision.
- English stays bundled. A failed or invalid catalog keeps the last good one, and a first launch shows English.
- Arabic and every other language still need review before entering `fomio_app_locales`.

## Risks

| Risk | Mitigation |
| --- | --- |
| An admin override with markup, a raw key or a bad placeholder | Discourse validates `%{…}` keys. The plugin validator rejects everything else and falls back to the next candidate. |
| Unreviewed wording reaches all app users immediately | Only administrators can override. Overrides are visible in the admin "overridden" filter. Terminology overrides are gated by a setting. |
| English edited in the app but not in the plugin | Generated YAML plus a parity check. Discourse marks overrides of changed sentences `outdated`. |
| Fallback leakage hides missing translations | No-fallback lookups, enforced by a spec. Every English value is listed in `fallback`. |
| Plugin keys missing from the admin editor on the deployed revision | Listing verified live for the plugin's `site_settings.*` keys in English and Arabic (2026-10-21). Saving an override, plural keys and the `fomio_app.*` namespace still need a staging check. |
| Catalog build cost with 482 I18n lookups plus override queries | Same order as v0.2.0, which already does per-key lookups. Measure, and cache by override and plugin revision if needed. |

## Implementation steps (each needs its own authorization)

1. **App repository, no backend:** generator for `server.en.yml` and the manifest from the bundled English, plus the parity check. Manifest `terminology` noun lists.
2. **Plugin v0.3.0 (local):** move Fomio keys to `fomio_app.*` locale files; builder resolution order above; no-fallback lookups; `fomio_app_terminology_overrides`; coverage fields; specs (override precedence, outdated/deprecated/invalid overrides, no fallback leakage, `pt_BR`, plural categories, markup rejection, parity with app English).
3. **Staging verification:** admin editor lists `fomio_app.*` keys (plugin keys in general are already listed live); an override changes the catalog revision and the app's text after refresh; a terminology override is ignored while the setting is off.
4. **Mapping review:** next candidate families, re-run the 49-locale coverage export.
5. **Deployment:** decided 2026-10-21 by the project owner: v0.2.0 is not deployed; the next deployment is v0.3.0. Then anonymous and member verification as in the [2026-10-16 record](validation/2026-10-16-live-deployment/README.md).
