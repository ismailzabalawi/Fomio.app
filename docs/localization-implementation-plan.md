# Localization implementation plan

Decision: English is the only guaranteed offline fallback. Fetch and retain only the user's chosen non-English interface language on demand. Keep Discourse authoritative for its existing terms, content, and locale rules.

Status: planned, 2026-10-04. No live settings or backend files were changed in this review.

## Live backend readiness check

Read-only inspection through the signed-in Fomio Admin browser session on 2026-10-04:

| Admin surface | Observed value | Effect on this plan |
| --- | --- | --- |
| [All site settings](https://meta.fomio.app/admin/site_settings/category/all_settings) | Default locale: English. Allow user locale: off. Locale from `Accept-Language`, cookie, and URL parameter: off. Support mixed text direction: off. | The site currently serves an English interface. We cannot assume that requesting another language in an app header changes Discourse responses. |
| [Content localization](https://meta.fomio.app/admin/site_settings/category/content_localization) | Content localization: off. Supported content locales: empty. Language switcher: none. | Post/category content translation is not enabled. It is separate from translating app controls; this plan does not require enabling it. |
| [Site texts, overridden](https://meta.fomio.app/admin/customize/site_texts?overridden=true&q=) | Existing overrides include `topics` → “Bytes”, `js.topic.title` → “Byte”, `js.topic.create` → “New Byte”, `js.category_title` → “Hub”, and `js.category.create` → “New Hub”. Other topic/category keys are also overridden. | The native app's current “discussion” and “community” labels do differ from live forum terminology. Map only reviewed, user-facing equivalents; do not globally replace words. |

Admin access was visible. One settings navigation timed out; a fresh tab loaded and the values above were read there. This is a snapshot of the displayed admin settings, not an API response or a test of a non-English user session. The deployed backend revision in `discourse-api-reference.md` should be rechecked before implementation. The local backend reference remained at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2` during this planning review.

## Sequence

1. **Inventory native copy.** List every visible and accessibility string in the current app. Classify each as Fomio-only copy, a Discourse term, server content, or a server validation message. Record the exact Discourse key behind each mapped term, including singular, plural, action, and sentence variants. Begin with Byte/Bytes and Hub/Hubs.
2. **Prepare native localization.** Give strings stable semantic keys and proper plural/format handling. Retain bundled English as the complete fallback. Existing Arabic editor strings can stay during migration, but the finished app should not claim an offline fallback in any language other than English. The app's active interface language, locale-sensitive formatting, and layout direction must change together.
3. **Define and add a backend read contract in a separately authorized backend task.** Expose a small public, read-only JSON response for approved app keys and one requested locale. It must apply the site's Discourse translations and site-text overrides, identify the resolved locale, return a revision/ETag, and never require an admin credential in the app. Review routes, controller, serializer/schema, permissions, settings, and request specs. The current `/extra-locales/` JavaScript bundles are browser assets, not this contract.
4. **Connect and cache one locale at a time.** On first online use, fetch the selected language; while it is unavailable, display the complete English interface. Cache a validated response atomically by site, locale, and schema. On later launches, show cached translations immediately and revalidate in the background, initially after 24 hours. Use `304`/ETag when supported. Limit retained non-English locales (for example, current plus one recently used language); never download all locales at install or launch.
5. **Align site language behavior.** Decide whether the app should follow the iOS app language or a Fomio language picker. If signed-in Discourse responses need to match, enabling `allow_user_locale` and setting a user's Discourse preference is a separate operational decision. Changing the site's default locale or enabling content translation is unnecessary for an English-fallback interface and should be decided separately. Verify the deployed settings and member behavior after any authorized change.
6. **Verify before enabling a language.** Test complete app chrome, plural rules, long text, dates/numbers, VoiceOver, mixed-script posts, and RTL/LTR navigation and composer behavior. Test cold offline launch (English), warm offline launch (cached chosen language), invalid/partial response, changed site-text override, stale cache, locale switching, and cache eviction. Record results per language rather than equating a Discourse locale's existence with native app support.

## Readiness gate

The backend is **not ready for automatic native translation inheritance today**: the site is English-only at the interface setting level, its content localization is off, and the reviewed Discourse source exposes translation bundles as JavaScript rather than a native JSON contract. Existing site-text overrides are usable source data for a future contract. No live setting needs to be changed to start steps 1 and 2. Step 3 and any backend changes require a task authorizing edits to `/Volumes/Develop/Projects/Dicourse`.
