# Localization and terminology strategy

Status: design, source review, and read-only admin settings inspection, 2026-10-04. No native localization API has been connected or tested on the deployed forum. See the [implementation plan](localization-implementation-plan.md) for the live settings snapshot and English-only fallback decision.

## What the app can promise

Fomio's native interface needs reviewed translations for navigation, accessibility labels, composer controls, validation, and offline use. English is the guaranteed offline fallback. The current project bundles English and Arabic strings for part of the editor; the rest of the interface still needs a string inventory and translation work. Discourse remains authoritative for community names, user content, permissions, and server error messages.

Forum terminology can change without an app release **only for app strings explicitly mapped to a server-provided terminology contract**. A generic Discourse translation override does not automatically replace a SwiftUI `Text` string. The app must know which semantic key it is displaying, and a native-readable response must provide a value for that key. Discourse translations also cannot supply native accessibility phrasing, Apple system UI, or app-only concepts by default.

The layout follows the selected app language and writing direction. SwiftUI mirrors many standard placements when the environment direction is RTL, but mixed-direction posts, custom UIKit editor components, images, chevrons, numerals, and VoiceOver order still need explicit checks. Changing a word on the server does not itself change the app language or layout direction.

## Source findings

Local backend checkout: `/Volumes/Develop/Projects/Dicourse`, HEAD `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2` on 2026-10-04. The checkout's unrelated untracked `docs/sidebar-outlet-discovery.md` was not used. These are source findings, not deployed-site verification.

| Surface | Source evidence | Native-app conclusion |
| --- | --- | --- |
| `GET /site/basic-info.json` | `app/controllers/site_controller.rb#basic_info`; `spec/requests/site_controller_spec.rb` | Public JSON includes the site's default `locale`; it is metadata, not a translation dictionary. |
| `GET /extra-locales/:digest/:locale/:bundle.js` | `config/routes.rb`; `app/controllers/extra_locales_controller.rb`; `lib/js_locale_helper.rb`; `spec/requests/extra_locales_controller_spec.rb` | Public browser asset for `main`, `mf`, and `overrides`. It is JavaScript, not a stable JSON API. Matching content digests get a one-year immutable cache header; an incorrect digest is not immutable. The overrides bundle can be empty. |
| Browser locale selection | `app/controllers/application_controller.rb#with_resolved_locale`; `lib/discourse.rb#anonymous_locale`; `config/site_settings.yml` | Signed-in requests use the user's effective locale. Anonymous locale selection through query, cookie, or `Accept-Language` depends on site settings. The app must not assume a header alone controls all responses. |
| Admin site texts / theme translations | `config/routes.rb` admin constraints; `app/controllers/admin/site_texts_controller.rb`; `app/controllers/admin/admin_controller.rb` | These routes are administrator-only and cannot be used with a member key. |

The browser loads `main`, `mf`, and optional `overrides` bundles through `app/views/layouts/application.html.erb`. That path demonstrates Discourse's browser behavior but does not establish a native JSON contract or automatic synchronization. No backend files were changed.

## Proposed native contract, when backend work is authorized

Provide a small, public, read-only JSON representation of the **Fomio-owned terminology keys**. It should be generated from the forum's current translated terms/overrides, with a stable schema and no administrative credentials in the app. The backend implementation, endpoint path, and deployment are still decisions to make; the following is a contract shape, **not an existing route**:

```json
{
  "schema": 1,
  "locale": "en",
  "revision": "content-digest",
  "terms": {
    "discussion.singular": "Thread",
    "discussion.plural": "Threads",
    "discussion.create": "New thread"
  }
}
```

Return only approved plain-text terms. Define singular, plural, action, and accessibility variants separately where grammar requires them. Validate locale against the site's supported locales; provide an explicit resolved locale and fallback. Bound payload size and disallow markup, formatting placeholders, arbitrary translation keys, and user-specific content. Use `ETag`/`If-None-Match` or an equivalent revision token. Confirm anonymous access and behavior under `login_required` in request specs and against the deployed site before use. Backend implementation requires a separate authorized task.

Do not parse or execute `/extra-locales/.../*.js` in the native app. The browser asset's assignment syntax, MessageFormat code, and locale data are not a native API contract. Do not call admin site-text routes or embed an administrator key.

## Cache and startup behavior

| Data | Local storage | Freshness / refresh | Offline behavior |
| --- | --- | --- | --- |
| Bundled English app strings | App bundle | New app version | Always available; fallback for any language that has not been downloaded. |
| Public terminology JSON, once available | Atomic file in Application Support, keyed by site origin + relative root + resolved locale + schema version | Render last good data immediately. Revalidate in background on launch/foreground when older than 24 hours; use conditional request. A successful changed revision replaces the file and updates visible labels. Manual refresh can bypass age check. | Use last good data; otherwise bundled app terminology. Never block startup. |
| Site default locale metadata | Small public cache or existing site metadata fetch | Revalidate with normal site bootstrap; do not fetch on every screen | Use the last known locale for site behavior; display English app strings if the selected language is unavailable. |
| Community names/content | Existing repository behavior | Follow each content endpoint's own freshness/permissions policy | Do not treat translation caching as an offline content or posting system. |

The 24-hour interval is an app policy proposal, not a Discourse header guarantee. A terminology change becomes visible at the next successful refresh (or manual refresh), not instantaneously while the device is offline. Honor server cache headers where compatible; use conditional requests to avoid downloading unchanged data. Coalesce concurrent refreshes and keep network failure silent when a valid cached/bundled value exists. A malformed response must leave the last good file intact.

Cache public terms separately for each site and locale. Do not mix terms across installations, do not store member data in this cache, and do not use it to determine permissions. If a future endpoint returns user-specific values, redesign isolation and invalidation before caching them. Clear obsolete schema versions on migration; sign-out does not need to delete truly public terms.

## Locale and lookup rules

1. Choose the app language using iOS's per-app language preference or an explicit in-app setting if one is later designed. Match it to a supported forum locale using an explicit mapping (`ar`, `en`, region variants), and keep the forum's resolved locale in the response. Do not guess that Discourse locale codes and Apple language identifiers always match.
2. Use a complete, validated cached/downloaded catalog for the chosen locale; otherwise display the complete English interface. For each mapped semantic key in an accepted catalog, a missing remote term falls back to its English app value. A partial or malformed catalog must not produce blank or mixed-language navigation.
3. Keep full sentences and grammatical plurals in the native localization system unless the contract explicitly supplies complete variants. Avoid string replacement such as replacing every occurrence of “discussion” with “thread.”
4. Display user-generated text as content, with its own writing direction. Do not relabel, translate, or mirror it merely because app chrome is RTL.

## Acceptance checks before claiming synchronization

- Inventory every app-facing string and identify which are native-only, server-owned content, or approved dynamic terms. Complete English and Arabic coverage and test a third unsupported device language fallback.
- Add one semantic term in fixture mode and verify launch from cache, stale background refresh, unchanged `304`, changed revision, malformed response, offline cold start, and site/locale separation.
- On the authorized backend change, review route, controller, serializer/schema, authorization, settings, and request specs. Then verify the deployed endpoint anonymously and with a member account. Record exact deployed revision, locale settings, relative root, cache headers, and sanitized response.
- Test Arabic RTL and English LTR navigation, mixed-script posts, the UIKit composer, Dynamic Type, long translated labels, and VoiceOver. SwiftUI's automatic mirroring is a starting behavior, not full acceptance evidence.

Until that contract exists and is live-verified, ship bundled localization and show server-provided community names/content. Do not promise complete Discourse translation inheritance or zero-update changes to all app copy.
