# 05 — Phase 1: configure Discourse into Fomio

Admin work only, no theme code. Every setting name below was checked against
the server's core (`7b4f0970`) on 2026-09-26; `SS:n` is the line in
`config/site_settings.yml` of that export (see 02 for how to make one).

**Proposed** values are starting points for the user to confirm, not
decisions. Tick an item when it is set on `meta.fomio.app`.

## Decisions of 2026-09-26

Read from the live instance, then decided by the user. Applied by the user
and read back from `/admin/site_settings.json` the same day. Supersedes the
**Proposed** column below where they differ.

| Setting | Found | Decision | Applied |
|---|---|---|---|
| `navigation_menu` | `sidebar` | `header dropdown` | yes |
| `top_menu` | `latest\|new\|unread\|hot\|categories` | `hot\|latest\|new\|categories` — `unread` left out. *Now permanent in effect: Unified New is on (02), which folds Unread into New › Replies and removes `unread` from the valid choices* | yes |
| `desktop_category_page_style` | `categories_and_latest_topics` | ~~`categories_boxes`~~ → **`categories_and_latest_topics`** (core's default) — changed back 2026-09-27 by the user's decision to follow the mockup's 02 Categories concept (3B, 07) | yes |
| `mobile_category_page_style` | `categories_with_featured_topics` | **`categories_only`** — 2026-09-27, user's decision (02 Categories concept): a compact category directory on phones, no featured-topic stacks (3B, 07) | yes |
| `default_trust_level` | 1 | 0 — at 1, the `newuser_*` limits never apply | yes |
| `newuser_max_replies_per_topic` | 3 | 5 | yes |
| `enable_category_group_moderation` | false | true | yes |
| `flag_sockpuppets` | false | true | yes |
| `default_email_digest_frequency` | 0 (off) | stays off until emails are designed | — |
| `nested_replies_enabled` | true | stays **on** — overrides the Q5 launch default | — |
| `discourse-topic-voting` | on, used by the Fomio category | keep | — |
| `tagging_enabled` (Q6) | false | stays off; revisit later | — |
| Social logins (Q8) | none | not now | — |
| Launch categories | existing ones | use as configured | — |
| `default_categories_tracking` | `""` | skip for now | — |
| `base_font` / `heading_font` | Lora / Raleway (live values before the change; this row had them swapped) | `source_sans_pro` / `roboto_slab` — the design pack's fonts, decided 2026-09-26 | **yes — set 2026-09-27** (3D, user's decision); site-wide, every theme |
| `post_menu_hidden_items` | `flag\|bookmark\|edit\|delete\|admin` | `flag\|edit\|delete\|admin` — bookmark (Save) shows on every post, as in the pack (3D, user's decision) | **yes — set 2026-09-27** |
| Theme 36 dark scheme | none | "Fomio AMOLED" (from `about.json`) | **no — to set** |

Already as proposed: logged-out reading, open signup, approval and
topic-creation groups, `default_list_filter` = `all` on every category,
`enable_user_tips` and `allow_anonymous_mode` off.
`newuser_max_links` is 0, stricter than core's 2; left as is.

## 1.1 Terminology

Discourse remains the source of rendered product text. The existing site-text
overrides remain active and unchanged for now, per the user's clarification
on 2026-09-26. Do not hardcode their wording in the theme; use Discourse's
translation output so the existing overrides continue to control what users
see. Do not edit or revert those overrides as part of implementation.

- [x] Preserve the 69 existing site-text overrides found on 2026-09-26.
      None were reverted or edited; this includes `category.post_template`.
      The current `js.topic.create` override renders "New Byte". Any future
      decision to change these strings belongs in Discourse's site-text
      controls, not theme literals. The theme implementation plan is in
      [07](07-production-implementation-plan.md).

## 1.2 Community structure

| Setting | Default | Proposed | Note |
|---|---|---|---|
| `max_category_nesting` (SS:417, hidden) | 2 | 2 | Category → subcategory. 3 would allow a third level; don't |
| `allow_uncategorized_topics` (SS:1409) | false | false | Every topic lives in a category |

Per category and subcategory (category settings → Appearance): `default_view`
(`hot`/`latest`/`top`), `default_top_period`, `sort_order`,
`default_list_filter` (`all` includes subcategory topics in the parent's list),
`subcategory_list_style`, `show_subcategory_list`. Posting review per category:
`topic_posting_review_mode` / `reply_posting_review_mode`.

- [x] Create the launch categories and their subcategories — the existing ones
- [x] `default_list_filter` = `all` on parent categories, so they show their subcategories' topics
- [x] `show_subcategory_list` = true, `subcategory_list_style` = `rows` on General (4), Off-topic Discussions (9) and Fomio (45), the parents with subcategories (3B, user's decision 2026-09-27; before: false / `rows_with_featured_topics`). Re-checked 2026-09-27: `default_view` is still unset on all 28 categories, and categories keep opening on Latest (user's decision)
- [x] `default_view` per category — left unset: categories open on Latest, the homepage (`/`) on Hot (decided 2026-09-26). The mobile bar's Home item goes to `/latest` (Q2). An unset category opens on Latest, not the first `top_menu` item

## 1.3 Native behaviour

### Homepage and navigation

| Setting | Default | Proposed | Note |
|---|---|---|---|
| `navigation_menu` (SS:3588) | `sidebar` | `header dropdown` | Phase 0: no sidebar. **Desktop only** — on mobile, core always uses the sidebar drawer (`services/navigation-menu.js`); the theme's bottom bar replaces it (Q2) |
| `top_menu` (SS:305) | `latest\|new\|unread\|hot\|categories` (Unified New default: `latest\|new\|hot\|categories`) | ~~`hot\|latest\|new\|unread\|categories`~~ `hot\|latest\|new\|categories` | Popular = `hot`. Must include `latest`. Anonymous visitors get `latest top categories hot`. `unread` isn't selectable under Unified New (02) |
| `default_homepage` (SS:318) | `""` (first `top_menu` item) | leave blank | |
| `header_dropdown_category_count` (SS:3831) | 8 | 8 | |
| `desktop_category_page_style` (SS:401) | `categories_and_latest_topics` | **`categories_and_latest_topics`** (superseded `categories_boxes`, 2026-09-27) | Keep the native Categories directory as the way to browse communities; no separate Explore screen is planned for launch. Desktop only; phones use `mobile_category_page_style`, now `categories_only` (2026-09-27) |
| `enable_welcome_banner` (SS:4234) | true | true | Carries "understands Fomio" for visitors until Phase 4 |

- [x] `navigation_menu`
- [x] `top_menu` — without `unread` (Unified New; not a pending choice)
- [x] Categories page style

### Ordering

`/hot` is `(likes − 1) / (age_hours + 2) ^ hot_topics_gravity` (default 1.2,
hidden, SS:4635), counting likes on every post of the topic. Leave the
defaults until real traffic says otherwise (Phase 6).

### Signup and logged-out access

| Setting | Default | Proposed |
|---|---|---|
| `login_required` (SS:682) | false | **false** — visitors must read without a wall (4.1) |
| `allow_new_registrations` (SS:732) | true | true |
| `invite_only` (SS:691) | false | false |
| `must_approve_users` (SS:687) | false | false; rely on the spam controls below |
| `enable_signup_cta` (SS:736) | true | true |
| `full_name_requirement` (SS:1079) | `hidden_at_signup` | `hidden_at_signup` — the shortest form |
| Social logins (`enable_google_oauth2_logins`, `enable_github_logins`, … SS:757–846; `sign_in_with_apple_enabled` in its plugin) | false | the user's call — each needs provider credentials |

- [x] Confirm or set each

### Trust levels and posting

Permissions are group lists (1 admins, 2 moderators, 10–14 = TL0–TL4).

| Setting | Default | Proposed |
|---|---|---|
| `default_trust_level` (SS:2824) | 0 | 0 |
| `create_topic_allowed_groups` (SS:2832) | `1\|2\|10` | unchanged — new members can create a topic |
| `approve_unless_allowed_groups` / `approve_new_topics_unless_allowed_groups` (SS:1769/1777) | `1\|2\|10` | unchanged — no approval queue |
| `newuser_max_links` / `_embedded_media` / `_attachments` / `_replies_per_topic` | 2 / 5 / 0 / 3 | review `newuser_max_replies_per_topic` — 3 may choke a lively first thread |
| `tl1_requires_*` / `tl2_requires_*` (SS:2947–2976) | core defaults | unchanged |

There is no reply-permission group setting; replies are gated only by
category permissions.

### Notifications and following

| Setting | Default | Proposed |
|---|---|---|
| `default_categories_watching` / `_tracking` / `_watching_first_post` (SS:4341–4353) | `""` | Keep empty: members choose categories and build their own feeds after signup (decision 2026-09-30) |
| `default_email_digest_frequency` (SS:4262) | 10080 (weekly) | weekly — the "returns" step of the journey |
| `default_other_notification_level_when_replying` (SS:4309) | 2 | 2 |

### Tags, bookmarks, search

| Setting | Default | Proposed |
|---|---|---|
| `tagging_enabled` (SS:4489) | true | see Q6 |
| `create_tag_allowed_groups` (SS:4521) | `1\|2\|13` | unchanged |
| `max_bookmarks_per_day` (SS:3408) | 20 | 20 |
| `search_experience` (SS:3806) | `search_icon` | `search_icon` — fits the boring header (2A) |
| `min_search_term_length` (SS:3739) | 3 | 3 |

### Moderation and anti-spam

| Setting | Default | Proposed |
|---|---|---|
| `enable_category_group_moderation` (SS:1286) | false | **true** — category moderators by group |
| `auto_silence_fast_typers_on_first_post` (SS:3343) | true | true |
| `newuser_spam_host_threshold` (SS:3307) | 3 | 3 |
| `max_new_accounts_per_registration_ip` (SS:3315) | 3 | 3 |
| `flag_sockpuppets` (SS:3304) | false | true |
| `discourse_captcha_enabled` (plugin) | false | only if spam signups appear |
| `ai_spam_detection_enabled` (discourse-ai, needs `discourse_ai_enabled` and an LLM) | false | later |

Akismet is not bundled at this version.

### Uploads and rate limits

Core defaults are sane for launch: images up to 10 MB (`max_image_size_kb`),
no attachments for new users (`newuser_max_attachments` 0),
`max_topics_per_day` 20, `max_topics_in_first_day` 3,
`max_replies_in_first_day` 10, `rate_limit_create_topic` 15s. Leave them;
revisit only on evidence.

## 1.4 Remove complexity

- [x] Keep `categories` in `top_menu`; native Categories, Hot and Latest are
      the launch discovery surfaces (2026-09-30 decision)
- [x] Turn off bundled plugins that are enabled but not part of the journey —
      check `/admin/plugins` (chat, gamification, calendar, …). Reviewed 2026-09-26:
      chat, gamification and calendar already off; the enabled ones (reactions,
      solved, poll, templates, checklist, details, local dates, lazy videos,
      presence, spoiler, topic voting) stay
- [x] `enable_user_tips` (SS:557) stays false
- [x] `allow_anonymous_mode` (SS:1156) stays false

## Open product questions

Decide each before the phase that needs it.

| # | Question | What core offers | Needed by |
|---|---|---|---|
| Q1 | **Tracked-feed tab on Home.** | `top_menu` can't hold it. `?f=tracked` works on any list (`/latest?f=tracked`, `/hot?f=tracked`) and means categories at Tracking or above. So the tab is a nav link to a native URL — theme work in 2C, no backend | 3A |
| Q2 | **Mobile navigation.** `header dropdown` is desktop-only; mobile keeps core's hamburger drawer (a sidebar in a sheet). | Setting covers desktop only. **Decided:** bottom bar, see below | 2A |
| Q3 | **The score on a topic card (▲ 382).** | (a) first-post likes: `op_like_count` is already in every topic-list item; liking from the card needs the `serialize_topic_op_likes_data` theme modifier. (b) `discourse-topic-voting`: bundled, per category, but **caps votes per user** (TL0 2 … TL4 10) — built for feature requests, not a feed. (c) `discourse-post-voting`: per topic, up/down on every post including the first. Recommendation: (a) | 3A |
| Q4 | **Watcher counts on a category ("32k followers").** | Not exposed to clients at all. Options: drop it, show `topic_count`/`post_count` instead (native), or a plugin later | 2B / 3B |
| Q5 | **Replies.** The plan says keep the flat stream. Core now has **native nested replies**, off by default: `nested_replies_enabled` (SS:1980), per-category `nested_replies_default`, `nested_replies_max_depth` 3, sort top/hot/new/old. It's a setting — the top rung. Try it, or keep flat for v1? | Setting | 3D |
| Q6 | **Tags.** On by default. Part of Fomio's model, or hide them for v1? | Setting | 1.4 |
| Q7 (settled 2026-09-30) | **Interest selection after signup (4.3).** | No picker and no admin-set defaults. Members choose categories through native tracking to build their own feeds | 4.3 |
| Q8 | **Social logins.** Which providers? | Settings + provider credentials | 4.2 |

### Launch defaults from the 2026-09-26 core check

These defaults keep Phase 1 native-first. Reopen one only when the launch
journey or real use demonstrates that the default is inadequate.

| Item | Launch decision | Why |
|---|---|---|
| Mobile navigation (Q2) | **Port the old theme's bottom bar** (`~/Projects/Fomio/apps/web/…/connectors/above-site-header/fomio-bottom-bar.gjs`) as the mobile navigation. Decided 2026-09-26; **built** in Phase 2A (`api-initializers/fomio-bottom-bar.gjs`, detail in 03). As built: **Home** → `/latest` · **Categories** → `/categories` · **New Topic** → `composer.openNewTopic()` · **Notifications** → opens core's user menu · **Profile** → `/u/:username`. Labels are core's strings (`home`, `filters.categories.title`, `topic.create`, `user.notifications`, `user.profile`), so the plan's "Discover", "Create" and "Me" became Categories, New Topic and Profile. Signed out: Home and Categories only. On mobile core's hamburger and header avatar are hidden while the bar shows — one navigation system. Port, not import: no custom notifications menu, auth intent, messages state, auto-hide or full-page reloads. Rendered through `api.renderInOutlet("below-footer", …)`; safe-area and bottom padding from core's footer-nav layout; hidden on auth and admin routes and while the composer is open. | No setting replaces the mobile drawer, and a bottom bar is the proven mobile pattern. "Theme" ranks above "Theme component" on the ladder, and the port is small (~100 lines). |
| Tracked feed (Q1) | **Built 2026-09-26 (2C):** an on/off filter in the nav row that toggles `f=tracked` on whichever list is showing (Latest, Hot, a category…), not a fixed link to `/latest?f=tracked`. Label is core's `user.tracked_categories`, so no theme string was needed. Detail in 03 and 08. | It is an existing native feed, so no backend, data model or feed algorithm is needed. |
| Topic score (Q3) | Use the first post's like count (`op_like_count`). | It is already available in the topic-list payload and represents ordinary community appreciation. Do not enable topic voting just to obtain a feed score. |
| Category watcher count (Q4) | Omit it. | Discourse does not expose a reliable count. Do not invent or estimate social proof; show only native, meaningful metadata if a category needs supporting context. |
| Nested replies (Q5) | ~~Keep the flat topic stream for v1.~~ **Superseded:** `nested_replies_enabled` and `nested_replies_default` stay on; 3D designs for core's nested view (user's decision, 2026-09-27). | Native nesting is tempting because it is a setting, but it changes the reading and moderation experience. The roadmap deliberately keeps the proven Discourse stream; revisit after launch or test it in one non-critical category first. |
| Interest picker (Q7) | **Out of scope for launch (2026-09-30).** No picker and no preselected categories; members build their own tracked feeds. | Follow the open-access Twitter/X example. Keep the native category tracking controls and Tracked feed; do not set `default_categories_*` for new accounts. |
