# Discourse API reference

## Category identity administration review — 2026-10-08

Reference HEAD freshly rechecked at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. Backend checkout remains read-only. Browser guest review of the deployed `/categories` directory confirms 11 public roots and 15 immediate children; this does not enumerate restricted/staff categories. Most rendered badges repeat `0088CC` and `square-full`; General uses `25AAE2`. See [assessment and proposed identities](category-identity-plan.md) for the exact ID inventory, descriptions and unresolved application checks.

Source review: `config/routes.rb` maps category updates through resource `PUT /categories/:id`; `CategoriesController#update` requires login and `guardian.ensure_can_edit!`, and permits `name`, `color`, `text_color`, `style_type`, `icon`, `emoji` and description. `CategoryGuardian#can_edit_category?` allows administrators or visible-category moderators when `moderators_manage_categories` is enabled. `Category` validates hex colors and emoji existence and defines square/icon/emoji styles. `BasicCategorySerializer` returns identity fields and logo uploads. `spec/requests/categories_controller_spec.rb` covers unauthenticated/nonstaff denial, updates, invalid emoji and description/About-topic synchronization. Specs were read, not run. Route/source availability is not proof that the deployed editor accepts every proposed icon.

Status: public taxonomy/rendered appearance **browser verified**; identity write contract **source reviewed**; deployed picker, authenticated edit/save/readback and native display **pending** because the current in-app browser is signed out. No deployed mutations or API keys used. Proposed names and identities are not recorded as applied facts. Native `CategoryMark` currently maps only a small icon/emoji subset; most proposed symbols need native mappings before full cross-client verification.

## Category and topic IA source review — 2026-10-06

Local checkout `/Volumes/Develop/Projects/Dicourse` rechecked at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`; only the previously recorded unrelated untracked `docs/sidebar-outlet-discovery.md` was present. No backend changes, server startup, request-spec execution or fresh deployed requests. The attached Discourse archeologist skill informed the trace; its historical Expo/relative-path wording does not change the native client's ownership or deployment status.

The [focused category/topic IA](category-topic-ia.md) records five diagrams, screen/state coverage, source feature packets and native gaps. New facts established **by source inspection**:

| Contract | Evidence | Finding and practical boundary |
| --- | --- | --- |
| Recursive category hierarchy | `db/structure.sql` categories/parent_category_id; `Category#parent_category/#subcategories`, `.subcategory_ids`; `categories_controller_spec.rb` recursive subsubcategory assertions | Children are categories; descendant traversal is bounded by `max_category_nesting`. Native directory and composer grouping currently enumerate only roots and immediate children, although the decoder recursively flattens embedded categories. Current deployed depth/taxonomy is unverified. |
| Directory completeness | `CategoriesController#fetch_category_list`; `CategoryList#find_categories/#paginate_results?`; `CategoryListSerializer`; category request specs “paginates results when lazy_load_categories is enabled” and “when there are many categories” | `include_subcategories=true` is not a complete-catalog guarantee under lazy/large-catalog pagination. Embedded child previews can be limited. The JSON serializer does not expose the model's Markdown next-page marker. The one-request native directory requires a verified completion/child-loading strategy before exhaustive search or hierarchy claims. |
| Category scope | Dynamic category/none routes; `ListController` generated actions; `TopicQuery#default_results`; `Category.subcategory_ids`; list request spec “returns topics from subcategories when no_subcategories=false” | Default explicit latest category request includes the category and descendants; `no_subcategories=true` or `/none/l/latest` restricts direct assignment. Topic visibility filters still apply. Native currently requests aggregate latest and has no scope parameter. Direct-only behavior remains deployed-unverified. |
| Latest ordering | `TopicQuery#list_latest/#apply_ordering`; category defaults in `ListController#category_default_view` | Default activity ordering uses bumped_at with pin/order rules; latest is not necessarily topic creation order. Explicit latest and category default-view routes have different intent. |
| Viewer permissions and status | `CategoryGroup.permission_types`; `Category.secured/.preload_user_fields!`; `CategoryGuardian`; `TopicGuardian#can_create_topic_on_category?/#can_create_post_on_topic?`; `TopicViewDetailsSerializer#include_can_create_post?` | full=1, create_post=2, readonly=3. Global create permission does not authorize every category. Topic reply capability is independent; closed/archived topics have privileged exceptions. Current native DTOs omit archived/slow-mode state and UI suppresses the main closed-topic Reply affordance. Per-member deployment behavior was not tested. |
| Nested topic navigation | `/n/` routes; `NestedTopicsController`; `NestedTopic::ListRoots/ListChildren/ShowContext`; `NestedReplies::PostTreeSerializer`; nested request specs for metadata, paging, context, visibility and placeholders | Initial roots carry topic/OP and requested/effective sort; later roots omit metadata. Context returns ancestors, target, siblings, effective sort and bus cursor; context=0 is focused-thread context. Cap settings can flatten descendants. Native currently requests new but drops effective_sort. A 404 does not distinguish disabled feature from missing/inaccessible target; PM reads redirect to flat routes. |
| Read side effects | `NestedTopicsController#track_visit/#should_track_visit?/.defer_mark_caught_up`; nested request specs “advances last_read_post_number to highest_post_number” and “marks the topic's unread notifications as read” | JSON without track_visit avoids the member catch-up branch; view counting is still deferred. Adding track_visit may mark the whole nested topic caught up rather than only visible replies. Native viewport reading/realtime policy remains unresolved. |

Verification commands and named request examples are recorded in each feature packet. Source searches were executed; suggested `bin/rspec` commands were not. Existing dated live observations below are retained without promotion to fresh verification. Unresolved: current deployment revision/settings; full catalog and ancestry retrieval; member permissions; About/media response fields; effective reply sorting; secure content; read tracking and realtime policy. No actual taxonomy, new deployed base URL, credentials or enabled plugin list was inferred for this map.

## Category identity and native theme mapping — 2026-10-06

**Goal:** Keep Discourse authoritative for category identity and color schemes while presenting them through native layouts. This replaces invented category initials and a mandatory purple interaction accent in the category/topic mockups. Source HEAD rechecked: `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`; no fresh deployed requests or backend changes.

**Entry point:** GET `/categories.json`, GET `/c/:id/show.json` (category packet above); GET `/site.json` → `SiteController#site` → `Site.json_for(guardian)` → `SiteSerializer`. Routes are in `config/routes.rb`. `/site/basic-info.json` exposes limited branding/header colors, not a substitute for full theme schemes.

**Client trigger:** Native bootstrap/category reads (proposed); Discourse web identity is demonstrated by `frontend/discourse/app/components/category-card-contents.gjs`, `CategoryNameLink`, which chooses icon/emoji from `style_type` or uses a square marker.

**Server path / data map:** `Category` enum `style_type` is square/icon/emoji. `BasicCategorySerializer` emits `color`, `text_color`, `style_type`, `icon`, `emoji`, descriptions and `uploaded_logo`, `uploaded_logo_dark`, `uploaded_background`, `uploaded_background_dark`. `CategoryUploadSerializer` exposes id/url/width/height. `db/structure.sql` categories stores identity/upload references; color_schemes/color_scheme_colors store scheme associations and named hex values. No writes are needed for this read/design scope.

**Permissions:** Category reads remain Guardian-filtered. `Site.json_for` and inherited application login policy apply; full site data is not guaranteed anonymously on login-required sites. `SiteController#basic_info` explicitly skips the login redirect. `SiteSerializer#user_themes` includes default/user-selectable themes and their light/dark scheme IDs and `only_theme_color_schemes`; `#user_color_schemes` respects selectability/theme restrictions. Do not require staff/admin theme endpoints or administrator keys.

**Async / realtime side effects:** No identity/theme writes, jobs or MessageBus subscription introduced. This review does not establish a native live refresh channel or cache invalidation policy.

**Serializer/JSON contract:** `SiteSerializer` emits `user_themes`, `user_color_schemes`, `default_light_color_scheme`, `default_dark_color_scheme`. `ColorSchemeSerializer#colors` resolves inherited/default color values; `ColorSchemeColorSerializer` emits name/hex/default_hex/is_advanced. Selectable schemes use `ColorSchemeSelectableSerializer`; do not assume they resolve inherited values identically to default scheme serialization. Missing default dark scheme can be null.

**Tests:** `spec/serializers/site_serializer_spec.rb`: “includes user-selectable color schemes”, “includes theme color schemes in user_color_schemes when modifier is active”, “includes only_theme_color_schemes flag in user_themes”, “includes default dark mode scheme” (including null). `spec/requests/site_controller_spec.rb`: permitted anonymous tag serialization and “is visible always even for sites requiring login” for basic_info. These specs were read, not run. Category identity fields were confirmed in serializer/model/schema and web component, not a new deployed payload.

**Safest extension plan:** Existing category/theme fields suffice for the mockups. A web theme component controls web presentation only. If native later needs a complete resolved palette beyond current client contracts, first evaluate existing member-readable payloads, then a narrowly scoped plugin read endpoint; no core patch is justified. Native should adapt semantic tokens, not execute theme JS or import web CSS.

**Native design decisions (proposals):** Header may prefer available logo/dark-logo, then configured icon/emoji/square. Unknown icon or failed asset falls back to that category's color square, not invented initials or parent identity. Category colors stay separate from UI tokens. Map primary→text, secondary→surface, tertiary→action/link/selection, and matching danger/success roles; derived muted/border colors need contrast verification. Header token roles and quaternary mapping require explicit design roles. Scheme dark surfaces follow the selected scheme; strict AMOLED is an optional native override, not a backend promise. Logo preference, native icon mapping, accessibility adjustments and fallback palette are native policy, not asserted Discourse web behavior.

**Native gap:** `Fomio/Data/DiscourseService.swift`, `CategoryDTO`, currently drops identity colors/style/assets. Native scheme decoding/selection and persistence are not implemented by this mockup task. No real deployed category assets or active theme palette were inferred. Theme/CSS overrides can differ from exposed palette data; selected member-theme precedence, asset authorization/URL resolution, custom emoji/icons, advanced tokens and safe contrast remain unresolved.

**Verification steps (executed source inspection):**

1. `git -C /Volumes/Develop/Projects/Dicourse rev-parse HEAD`
2. `rg -n 'color|style_type|icon|emoji|uploaded_' /Volumes/Develop/Projects/Dicourse/app/serializers/basic_category_serializer.rb`
3. `rg -n 'user_themes|user_color_schemes|default_light_color_scheme|default_dark_color_scheme' /Volumes/Develop/Projects/Dicourse/app/serializers/site_serializer.rb`
4. `rg -n 'color schemes|default dark mode scheme|only_theme_color_schemes' /Volumes/Develop/Projects/Dicourse/spec/serializers/site_serializer_spec.rb`

## User-confirmed category depth — 2026-10-06

The user confirmed one level of subcategories: root category → immediate child (two total category levels). This is the authoritative design scope for the Fomio mockups and supersedes earlier deeper-category UI proposals. It is user-provided site/product information, not a fresh HTTP/settings verification. Source `max_category_nesting` and recursive helpers still support configurable deeper hierarchy; their evidence above remains valid. Nested reply depth is a separate contract. Integration must report any actual taxonomy mismatch rather than silently dropping categories. The focused IA maps now show only root/child navigation.

## Source baseline

- Inspected: 2026-10-02.
- Local checkout: `/Volumes/Develop/Projects/Dicourse` (exact supplied path).
- Git HEAD: `efbd165d6182b1c31cd8afd224625aef300689bd`.
- An untracked `docs/sidebar-outlet-discovery.md` was present; it was not used to establish API behavior.
- Backend project instructions: `AGENTS.md`, which links to `AI-AGENTS.md`.
- No backend files were changed. No server was started and no HTTP contracts were tested.

This baseline establishes source access, not a working deployment or a match with production. Recheck HEAD and relevant local changes when updating contracts. Local paths are developer-specific; update this document if the checkout moves.

## Where to establish a contract

### MVP design status — 2026-10-03

The [finalized MVP mockups](design/mvp-design-handoff.md) passed a representative 117-render browser layout matrix with zero flags. This provides presentation evidence only. Community previews, photo uploads, drafts, Likes/Saved, notification targets and posting outcomes remain simulated; no new backend revision check, source contract review or live request was performed in the design/documentation pass. All endpoint verification statuses below remain unchanged. Deployment resources, enabled features, per-user scopes, draft persistence and pending-review visibility remain unresolved. Recheck backend HEAD before implementing.

### Imported research status — 2026-10-02

The [rebuilt IA](information-architecture.md) adds explicit review gates for profile/activity, bookmark management, private messages, category hierarchy resolution, tracked-sort combinations, nested replies, editor modes and draft recovery. These remain **unverified for the native app**. Backend HEAD was rechecked and unchanged while rebuilding the map; no new contract review or live request was performed. Historical browser success and web user-session permissions are not evidence of user-API-key access.

Prior Fomio research is preserved in the [IA build guide and reference snapshot](ia-build-guide.md), with file hashes and checkout provenance. Backend HEAD was rechecked during import: `efbd165d6182b1c31cd8afd224625aef300689bd`, matching the initial baseline. This import performs no new endpoint contract review or live verification.

The imported composer audits include a different backend revision, `7b4f0970506fb0ce7d4b6a851d252ace418330c8`, and historical browser-session observations. They do not prove availability with per-user API keys on the eventual app deployment. Existing endpoint statuses remain unchanged.

Additional audit candidates from imported research: composer messages, similar topics, draft list/show/save/delete (sequence and owner handling), mention/hashtag autocomplete, Onebox, first-post topic metadata edits, upload lookup/direct-storage flows, presence, and conditional form templates. Status: **historical reference imported; current contracts and deployment availability unverified**. Inspect routes, controllers, serializers, authorization and request specs before implementing each. AI/poll/forms/chat and other plugin or setting-dependent behavior remain unresolved for the iOS deployment.

Paths below are relative to the backend checkout.

| Concern | Source |
| --- | --- |
| Core routes and HTTP methods | `config/routes.rb` |
| Dynamic feed filters | `lib/discourse.rb`, `Discourse.filters` |
| Inputs and response behavior | `app/controllers/` |
| JSON fields and conditional fields | `app/serializers/` |
| Permissions | `lib/guardian.rb`, `lib/guardian/`, controller checks |
| Per-user key authentication | `app/controllers/user_api_keys_controller.rb`, `lib/auth/default_current_user_provider.rb`, `app/models/user_api_key.rb` |
| Request examples and expected behavior | `spec/requests/` |
| Plugin endpoints | `plugins/*/config/routes.rb`, plugin registration and controllers |
| Feature availability | `config/site_settings.yml`, plugin settings, deployed site configuration |

Useful serializers include `topic_list_serializer.rb`, `topic_view_serializer.rb`, and `post_serializer.rb`. Useful request specs include `topics_controller_spec.rb` and `user_api_keys_controller_spec.rb`.

## Initial route inventory

Status for every row: **source route identified; full contract and live behavior unverified**. Paths below use the JSON form where appropriate. A site's relative URL root must also be respected. Do not treat this table as a complete client specification.

| App capability | Method and path | Controller / notes |
| --- | --- | --- |
| Latest feed | `GET /latest.json` | `list#latest`; generated from `Discourse.filters` |
| Hot feed | `GET /hot.json` | `list#hot`; `hot` exists in this checkout's filter list |
| Community directory | `GET /categories.json` | `categories#index` |
| Community details | `GET /c/:id/show.json` | `categories#show` |
| Community feed | `GET /c/<category_slug_path_with_id>/l/latest.json` | Dynamic category filter route; verify slug/ID resolution |
| Community tracking | `POST /category/:category_id/notifications` | `categories#set_notifications`; reads `notification_level` |
| Discussion | `GET /t/:slug/:topic_id.json` | `topics#show` |
| Specific reply | `GET /t/:slug/:topic_id/:post_number.json` | `topics#show`; distinguish post number from post ID |
| Additional discussion posts | `GET /t/:topic_id/posts.json` | `topics#posts`; batch parameters still need inspection |
| Create discussion or reply | `POST /posts.json` | `posts#create`; controller supports `raw`, `topic_id`, `category`, and `reply_to_post_number`; inspect complete title and creation requirements |
| Edit post | `PUT /posts/:id.json` | `posts#update`; inspect update payload separately |
| Media upload | `POST /uploads.json` | `uploads#create`; multipart and external-upload contracts need audit |
| Search | `GET /search.json`, `GET /search/query.json` | `search#show`, `search#query`; choose contract after inspection |
| Notifications | `GET /notifications.json` | `notifications#index` |
| Mark notifications read | `PUT /notifications/mark-read` | Collection route to `notifications#mark_read`; verify targeting parameters |
| Bookmarks | `POST /bookmarks.json` | `bookmarks#create`; inspect bookmarkable type and ID requirements |
| Request user API authorization | `GET /user-api-key/new` | `user_api_keys#new`; browser authorization flow, not direct credential collection |

Reactions and chat each have local plugin routes under `plugins/discourse-reactions/` and `plugins/chat/`. Their presence on disk does not establish that Fomio enables them.

## Authentication observations

The current-user provider reads `User-Api-Key` and `User-Api-Client-Id` headers. It looks up an active hashed user key, enforces key scopes and rate limits, and rejects suspended or inactive users. These observations come from source inspection; the browser authorization flow is now implemented, but remains unverified against a deployed site.

Before implementing authentication, verify allowed groups, scopes, callback rules, key issuance/encryption, expiry/revocation behavior, and client identification. Store member secrets in Keychain. Never ship an administrator key.

## Contract verification workflow

For each endpoint:

1. Confirm route, method, format, and any plugin mount prefix.
2. Read controller inputs, validation, service/model behavior, and Guardian checks.
3. Inspect serializers for response envelope, optional fields, and permission-dependent actions.
4. Read relevant request specs for anonymous, authenticated, and denied cases.
5. Verify against the supplied running instance and record deployment version, settings, and enabled plugins that affect behavior.
6. Save sanitized fixtures and document pagination, error responses, rate limits, and retry behavior before implementing Swift models and calls.

Use explicit statuses: source identified, contract reviewed, live verified, or blocked. Record evidence and unresolved questions; do not promote a source observation to live verified without a real request.

Priority audits: authentication → feeds/categories → discussion post-stream pagination → composer/create/edit → uploads → tracking → notifications and links. Check pending moderation responses and ambiguous write failures before implementing automatic retries. Draft recovery and duplicate-post prevention need their own design; route discovery alone does not solve them.

## Localization contract review — 2026-10-04

Reference HEAD rechecked at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`; the unrelated untracked `docs/sidebar-outlet-discovery.md` was not used. Source evidence: `config/routes.rb`, `app/controllers/extra_locales_controller.rb`, `lib/js_locale_helper.rb`, `app/views/layouts/application.html.erb`, `app/controllers/site_controller.rb`, `app/controllers/application_controller.rb`, `lib/discourse.rb`, `app/controllers/admin/site_texts_controller.rb`, `app/controllers/admin/admin_controller.rb`, `spec/requests/extra_locales_controller_spec.rb`, and `spec/requests/site_controller_spec.rb`. No backend changes or live localization requests were made.

`/site/basic-info.json` exposes the default locale, not a native translation dictionary. `/extra-locales/:digest/:locale/{main,mf,overrides}.js` is a public browser JavaScript asset; its digest controls immutable caching, and the overrides bundle may be empty. Admin site-text and theme-translation routes require administrator access. Anonymous locale negotiation via query/cookie/`Accept-Language` is setting-dependent; a signed-in user's effective locale takes precedence. **Status: source contract reviewed for these observations; native JSON terminology endpoint absent; deployed behavior unverified.** See [localization strategy](localization-strategy.md) for the proposed app contract and cache policy. An app-visible terminology change without an app update remains blocked on an authorized backend endpoint and deployed verification.

### Live admin settings inspection — 2026-10-04

Using the signed-in Fomio Admin browser session, inspected settings and site texts read-only. The displayed default locale is English; `allow_user_locale`, locale selection from `Accept-Language`/cookie/URL parameter, support for mixed text direction, and content localization are off. Supported content locales are empty and the content language switcher is `none`. Site texts already override topic/category labels, including “Byte”, “Bytes”, and “Hub”; this corrects the assumption that Fomio has no terminology differences. No site setting or site text was changed. This is an admin UI snapshot, not a live native translation endpoint check. See [localization implementation plan](localization-implementation-plan.md) for exact surfaces, decisions, and remaining gates.


## Deployment snapshot — 2026-10-04

Observed read-only from `https://meta.fomio.app` through an admin browser session and public JSON requests. No settings were changed.

- Version: `Discourse 2026.8.0-latest`, commit `7b4f0970506fb0ce7d4b6a851d252ace418330c8`. The local reference (`d4296c5e`) is 1,469 commits ahead; the deployed commit is its ancestor. Diffs in the posts, user-API-key, nested-topics, list and uploads controllers between the two revisions do not change the requests this app makes (user-API-key redirect now preserves an existing callback query; nested redirects respect the relative root; edit/whisper authorization tightened).
- Nested replies exist at the deployed commit (`nested_topics_controller.rb`, `/children/:post_number` route, `nested_post` in `PostsController`). Settings: `nested_replies_enabled` true, `nested_replies_default` true, `nested_replies_max_depth` 3, `nested_replies_cap_nesting_depth` true, `nested_replies_default_sort` top, hot sort disabled.
- User API keys: `allowed_user_api_auth_redirects` includes `fomio://auth_redirect` and `fomio://*`; `allow_user_api_key_scopes` = read, write, message_bus, push, notifications, session_info, one_time_password; `user_api_key_allowed_groups` = 1, 2, 0 (everyone); `revoke_user_api_keys_unused_days` 180.
- Access/posting: `login_required` false, `invite_only` false, local logins enabled, `allow_uncategorized_topics` false, `default_composer_category` 4, `tagging_enabled` false, `min_topic_title_length` 5, `min_first_post_length` 20, `min_post_length` 2, `approve_post_count` 0.
- Uploads: local storage (`enable_s3_uploads` false), `secure_uploads` false, `max_image_size_kb` 10240, image extensions only.
- Enabled plugins: checklist, details, lazy videos, local dates, poll, presence, reactions, solved, spoiler alert, templates, topic voting. Chat and AI are disabled.
- Anonymous `GET /latest.json`, `/categories.json`, `/t/:id.json` and `/n/:slug/:id.json` returned 200 with the fields the adapters decode (`topic_list.topics`, `more_topics_url`, `users`; `topic`, `op_post`, `roots`, `has_more_roots`, `page`). This is a guest read check only; no endpoint is promoted to live verified until the app itself makes the request.

## Live app check — 2026-10-04

Debug build (live adapter, guest, no credentials) on the iPhone 17 Pro simulator against `https://meta.fomio.app`, plus anonymous public JSON requests. Backend reference unchanged at `d4296c5e`; deployed commit as in the snapshot above. No settings were changed and no account was used.

| Request | Observed |
| --- | --- |
| `GET /categories.json?include_subcategories=true` | 200. Communities render with subcategory chips. Anonymous `can_create_topic` false and `permission` absent, so guest `canCreate` is false (the guest "New discussion" button is the intentional sign-in prompt). |
| `GET /latest.json?page=N` | 200. Home feed renders; `more_topics_url` present. |
| `GET /c/:id/l/latest.json` | **301** to `/c/:slug/:id/l/latest.json` (same origin). `SameOriginDelegate` follows it and the feed renders; costs one extra round trip per category load. |
| `GET /n/:slug/:id.json`, `/children/:n.json`, `/context/:n.json` (with and without `context=0`) | 200 with the documented keys; page 1 omits `topic`/`op_post`. Fallback slug `topic` also resolves. Topic 5 roots are two `deleted_post_placeholder` posts with empty `cooked` and no `username`. |
| `GET /search.json?type_filter=topic` | 200; results and highlighted blurbs render. A stop-word-only query (`the`) returns no posts/topics keys. |
| `GET /u/:username.json`, `/topics/created-by/:username.json` | 200 with decoded fields. |
| Anonymous `GET /session/current.json` / `/notifications.json` | 404 / 403, as expected without a key; the app shows sign-in prompts instead of calling them. |
| `GET /user-api-key/new` (from `ASWebAuthenticationSession`) | **Client defect found and fixed 2026-10-04.** The generic error came from public-key parsing: the app sent base64 `+` unescaped, Rails decoded it as a space and `OpenSSL::PKey::RSA.new` failed (`InvalidParameters(:public_key)`, rescued into `generic_error`). After the fix the app's own request passes pre-consent validation and reaches the login page. Consent, callback and member identity are still live-unverified; see “User API key pre-consent failure — diagnosis” below. |

Rendering facts established: cooked posts use `<img class="emoji" width="20">` for emoji (for example `/images/emoji/apple/heart.png`). These are now kept inline as their shortcode text instead of becoming photo blocks (`HTMLContent.inlineEmoji`). Topic `title` and `fancy_title` both carry raw shortcodes (`:wave:`). Neither the title nor the inline emoji is converted to Unicode yet.

## Native implementation source review — 2026-10-03

Current reference HEAD: `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`, rechecked before implementation and again during the documentation handoff on 2026-10-03. Only the unrelated untracked `docs/sidebar-outlet-discovery.md` is present. Backend unchanged; no backend server or request specs were run. Deployed verification was blocked pending base URL, version alignment, settings/plugins, callback/scopes and test users; see the 2026-10-04 deployment snapshot above for the resolved items. Test users remain pending. Swift tests use local fictional data, not live-response recordings.

| Contract | Source evidence reviewed | Implementation / verification status |
| --- | --- | --- |
| Browser user key | `user_api_keys_controller.rb` new/create/redirect validation; `app/services/user_api_key/device_auth/crypto.rb`; `user_api_key_scope.rb`; `auth/default_current_user_provider.rb`; `spec/requests/user_api_keys_controller_spec.rb` RSA/padding/callback/group/scopes cases | Contract reviewed for classic browser flow: RSA 2048 OAEP SHA-1, nonce, client ID, encrypted callback payload. Query values must be form-safe: `+` is sent as `%2B` (`LiveConfiguration.url`), covered by `testUserAPIKeyAuthorizationPublicKeySurvivesRailsQueryDecoding`. Pre-consent validation live verified (anonymous 302 to `/login`); consent, callback decryption, Keychain and `session/current.json` are not live verified. |
| Latest/category feeds | Dynamic routes in `config/routes.rb`; `list_controller.rb`; `TopicListSerializer`, `TopicListItemSerializer`, `ListableTopicSerializer`; `Guardian`; list/category request specs | Source-informed adapter uses `topic_list.topics`, user mapping and `more_topics_url`. Feed excerpt/media are optional. Live availability and site-specific required fields blocked. |
| Categories | `categories_controller.rb#index/fetch_category_list`; `CategoryList`, `CategoryListSerializer`, `CategoryDetailedSerializer`, `BasicCategorySerializer`; category request specs for hidden/permitted subcategories | Contract reviewed: `include_subcategories=true` includes recursive `subcategory_list`; `parent_category_id` preserves hierarchy. Global `can_create_topic` plus category permission 1 (full) gates new-topic choices. Server still validates group/trust/tag rules. |
| Nested replies | `/n/:slug/:topic_id` show/children/context routes; `NestedTopicsController`; `NestedTopic::ListRoots/ListChildren/ShowContext`; `NestedReplies::PostTreeSerializer/TreeLoader/Sort`; nested controller request specs | Contract reviewed at source: `nested_replies_enabled` and Guardian visibility required; JSON roots include initial topic/OP, subsequent pages omit metadata; child/context fields documented below. User-key `read`/`write` match GET at source, but no live user-key request verified. Release requires nested capability. |
| Posting/moderation | `PostsController#create/create_params/backwards_compatible_json`; `NewPostManager`; `NewPostResultSerializer`; Guardian; post request specs for nested result/queue | Contract reviewed for raw/title/category/topic/reply target with `nested_post=true`. `action=enqueued` is distinct from a published post. API memoization is not treated as a client idempotency guarantee. Live per-user posting and pending visibility blocked. |
| Upload | `UploadsController#create`, UploadCreator/serializer and Guardian, upload request specs for composer/error/anonymous | Multipart adapter uses upload_type composer, file and returned short URL. Deployment limits, secure media, direct storage and actual upload permissions remain unverified. |
| Likes | `PostActionsController`, PostActionCreator/Destroyer, PostSerializer actions_summary, Guardian and post-action request specs | Contract reviewed: action type 2 is Like; create/destroy use post ID; count/acted/can_act are optional permission fields. No votes. |
| Saved | `BookmarksController`, BookmarkManager, UsersController#bookmarks, user post/topic bookmark serializers, bookmark/users request specs | Source-informed create/delete/list adapters; bookmarks use bookmarkable type Post and post ID, returned bookmark ID for deletion; list linked_post_number is separate. Plugin bookmark types may not resolve to discussion destinations and are omitted from this MVP list. |
| Notifications | `NotificationsController#index/mark_read`; NotificationSerializer; Guardian; notification request specs including user API access | Contract reviewed: offset/limit, total rows, explicit id mark-read. The client filters replied/mentioned locally because server type filtering depends on the recent-notification branch. Notification route resolution occurs before marking read. Live exact-target and read-state behavior blocked. |
| Search/profile | search/users/list controllers, search/basic-user/profile serializers and related request specs | Source-informed adapters only; full deployment-specific search result order/content and profile access are pending. Profiles use native plain bio and recent created discussions. |

### Nested response shape and guardrails

- Roots: `roots`, `has_more_roots`, `page`; page 0 adds `topic`, `op_post`, `sort`, `effective_sort`. Roots/children are PostSerializer data plus `children`, `direct_reply_count`, `total_descendant_count`.
- Children: `/children/:post_number.json`, params `page`, `sort`, `depth`; response `children`, `has_more`, `page`. Site depth-cap settings may flatten descendants; never infer a missing ancestor or hierarchy from a post number.
- Context: `/context/:post_number.json`, optional `context=0` for focused thread; `topic`, `op_post`, `ancestor_chain`, `ancestors_truncated`, `siblings`, `target_post`, `effective_sort`. Private/inaccessible and disabled cases can all return 404, so a single 404 is not proof that the site capability is disabled.
- Deleted placeholders may omit `topic_id`, author and raw; decoder must keep inherited topic identity and show the placeholder instead of failing the whole page.
- Native default `sort=new`; backend `effective_sort` may differ. No ranking or vote UI is introduced.
- Native read requests do not set `track_visit`; this avoids assuming the source's broad catch-up behavior matches viewport reading. Production read-tracking semantics remain pending.

### Screen Pack fields — 2026-10-03

The Screen Pack parity pass mapped these optional fields from source-reviewed serializers. None are live verified:

- Post `name` and `created_at` (display name for initials, relative age). An empty name falls back to the username.
- Notification `created_at` for the age, plus type 1 (mentioned) and 2 (replied) for the glyph and wording.
- User `created_at` for “Joined”.
- Search post `username` for “Reply #n by …”.
- Quotes are sent as `[quote="author, post:n, topic:id"]` BBCode ahead of the writing in `raw`.

These are deliberately not mapped and display only in fixtures: directory “Latest” previews (no per-category latest topic is requested), the Restricted badge (a visible Discourse category is accessible; denial surfaces from a 403/404), and bookmark category/post-author labels in Saved. Confirm the bookmark list serializer fields before adding them.

### Unresolved integration requirements

No member endpoint is live verified. Later guest reads and the pre-consent user-key GET are recorded above and below; they do not establish member permissions. Remaining work includes callback delivery, signing, user-key permissions, site text/tag/required-field posting constraints, secure media retrieval, search exact-result behavior, pending-author visibility, and a provable uncertain-write reconciliation contract. The live reconcile adapter deliberately returns unresolved. No administrator credentials were embedded.

## Expanded native composer — 2026-10-04

Rechecked local backend HEAD: `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. No backend modifications.

| Contract | Source reviewed | Fixture/contract tests | Live member verification |
| --- | --- | --- | --- |
| Similar discussions | `similar_topics_controller.rb`, `similar_topic_serializer.rb`, `Topic.similar_to`, similar-topic request specs; title required, optional raw, `[]` fast path or referenced topic envelope; Guardian-visible results | Native adapter handles empty and topic envelope, member headers; 750 ms cancellation/debounce; errors don't affect Post | Pending; insertion/UI requests disabled by default |
| Onebox | `onebox_controller.rb`, Oneboxer, Onebox request specs; requires login; plain cooked HTML, category/topic context, one active preview/user, 404/429 | Member-header adapter; serialized native preview requests; only heading/paragraph text becomes native metadata, original URL remains raw; scripts/embeds never execute | Pending; disabled by default |
| Category template | `basic_category_serializer.rb` exposes `topic_template` | Category model/decoder and empty-body destination insertion | Pending deployed serializer/member response |
| Poll | poll builder/settings/validator and request/spec constraints; named regular/multiple poll, title line and option bullets, selection bounds | Native validated form, unique poll names; unsupported attributes preserved for Markdown | Pending member/group/site permission. Live insertion hidden; server-owned voting/rendering remains original-post fallback |
| Details/spoiler/local date | Plugin markdown implementations and local-date builder | Native forms, supported-shape editing, details/spoiler/date cooked rendering | Pending; live insertion hidden |
| Table/code | Discourse Markdown/native cooked projection | Native table/code forms and rendering, pipe/code fence handling | Pending live round-trip; core Markdown tools remain available |
| Inline upload | Existing composer upload contract; prior site-settings snapshot reported 10240 KB image limit | Sequential uploads, retained local files, v2 migration, removed-response suppression, inline-only serialization | Pending actual member uploads and current settings; maximumUploadBytes remains configurable rather than treating the prior observation as fresh verification |

`ComposerCapabilities` defaults conservatively. Plugin enablement observed in an admin settings snapshot is not a per-member capability proof. Test injection uses fixture capabilities; the live adapter's defaults do not enable plugins, similar discussions, or Onebox.

### Live member authorization attempt — 2026-10-04

The native app’s normal ASWebAuthenticationSession flow reached `meta.fomio.app` on iPad Pro 11-inch (M5), iPadOS 26.1. The authorize-application page reported that it was unable to issue user API keys and that the feature may be disabled by the site administrator. No member credential was entered, no key was issued, and no live member posting/upload/preview/plugin checks were completed. Evidence: `editor-captures/live-user-api-disabled.png`. The later diagnosis below establishes that this was a client URL-encoding defect, not evidence that deployed issuance is disabled. Backend source was not modified.

Admin log follow-up, 2026-10-04: the signed-in browser exposed Admin → Logs → Error logs, but filtering the visible retained entries for `device_auth.authorization.rendered_generic` returned no match, including with Info enabled. This did not reveal the original exception; the later A/B diagnosis below established the client cause. No site setting was changed.

### User API key pre-consent failure — diagnosis, 2026-10-04

Revisions: local reference HEAD rechecked at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2` (only the unrelated untracked `docs/sidebar-outlet-discovery.md`); deployed `7b4f0970506fb0ce7d4b6a851d252ace418330c8`. The code below was read at the deployed commit; `app/services/user_api_key/device_auth/crypto.rb` is identical at both. Backend files were read only.

- **Trace.** `GET /user-api-key/new` → `UserApiKeysController#new` → `user_api_key_authorization_model`, which runs `require_params`, `find_client`, `require_client_params`, `validate_params` (allowed scopes, registered client scopes, `parsed_public_key`, `validate_padding`) and `validate_auth_redirect` *before* `redirect_anonymous_to_login`. `UserApiKey::DeviceAuth::Crypto.parse_public_key!` wraps `OpenSSL::PKey::RSA.new` and converts a parse failure into `Discourse::InvalidParameters(:public_key)`, which `#new` rescues into `{state: "generic_error"}`. The request spec “renders an error for a non-RSA public key even when not logged in” asserts this. Specs pass params through the Rails test client, which encodes them, so they cannot catch a client that leaves `+` unescaped.
- **Why the logs were empty.** `#new` reports the failure through `UserApiKey::DeviceAuth.trace`. That writes a `Rails.logger.info` line only when `verbose_user_api_key_device_auth_logging` is enabled; it is not an error-log entry. The setting was not changed.
- **Client cause.** `AuthenticationService.signIn()` put the PEM in `URLQueryItem`. `URLComponents` leaves `+` literal, and Rack form-decodes `+` as a space. A 2048-bit PKCS#1 key's base64 almost always contains `+`; locally, Rack-style decoding of the app's exact URL produced `OpenSSL::PKey::PKeyError` (OpenSSL gem 4.0.2, Ruby 3.4.7).
- **Live evidence (anonymous, read-only, no key can be issued).** Same freshly generated key and parameters, sent with `Accept: application/json`: the app's encoding returned `200 {"state":"generic_error"}`; the same URL with only `+` → `%2B` in `public_key` returned `302` to `/login`. After the fix, the native app on iPhone 17 Pro (iOS simulator) opened the Discourse login page instead of the error page. No credential was entered and no consent was granted.
- **Follow-up native check.** A fresh Debug build on iPhone 17 Pro/iOS 26.1 again opened the `meta.fomio.app` login form through the system authorization sheet. The simulator UI inspection tool exposed only the Fomio view behind that sheet, so it could not target the web form fields. The supplied test account was not entered in this run; callback and current-user lookup remain unverified. No account data, key or callback payload was captured.
- **Callback fallback fix.** The app's existing `onOpenURL` handler sent `fomio://auth_redirect` to the community-link router, where it was rejected, while the bundle did not register the `fomio` scheme. `Info.plist` now registers the scheme, and `AppState.handleLink` passes the exact callback destination to `AuthenticationService.receiveCallback` first. The web-session completion and incoming-URL fallback share one checked continuation, so only the first result resumes sign-in; decryption and nonce checks still run afterward. The rebuilt app and all 59 unit/contract tests passed on iPhone 17 Pro/iOS 26.1. Delivery of a real issued-key callback, Keychain save and `session/current.json` still require a completed live consent run.
- **Post-callback decoding fix.** A user retest confirmed that the incoming-URL fallback returned to Fomio but did not establish a member session. Source at `UserApiKeysController#create` wraps the RSA ciphertext with Ruby `Base64.encode64`, then URL-escapes it into `payload`; the resulting value contains line breaks. Foundation's default `Data(base64Encoded:)` rejects line breaks, so the app's callback guard failed before decryption or Keychain save. `AuthenticationService.encryptedPayload(from:)` now removes only CR/LF and then applies strict Base64 decoding. A regression test constructs a fictional OAEP ciphertext, wraps it as Discourse does, passes it through the callback URL, verifies decryption, and rejects other invalid characters. The rebuilt app and all 60 unit/contract tests pass on iPhone 17 Pro/iOS 26.1. A new real consent run is still needed to verify Keychain save and `GET /session/current.json`.
- **Fix.** `LiveConfiguration.url(_:query:)` now percent-encodes `+` as `%2B` in all query values. This also stops search terms such as “C++” reaching the server as spaces. Request construction is extracted into `AuthenticationService.publicKeyPEM(_:)` and `authorizationURL(configuration:clientID:nonce:publicKeyPEM:)` without behaviour change. Regression tests `testUserAPIKeyAuthorizationPublicKeySurvivesRailsQueryDecoding` and `testSearchTermPlusIsNotDecodedAsSpace` fail without the fix and pass with it.
- **Status.** Pre-consent validation: **live verified** for scopes `read,write,notifications,session_info`, callback `fomio://auth_redirect` and `padding=oaep`. A later simulator launch restored the previously authorized `FomioTester01` member and displayed the live Me profile, which verifies a stored member credential and successful current-user lookup on that launch. The original issuance/callback/decryption sequence was not observed end to end in this run. Canceled, denied, revoked and expired flows remain unexercised.
- **Unresolved assumptions.** The site settings still match the 2026-10-04 snapshot. No registered `UserApiKeyClient` row constrains a reused `client_id` (a new install generates a fresh UUID). The JSON callback payload (key, 36-character UUID nonce, push, api, optional expiry) fits the 214-byte OAEP limit for a 2048-bit key; checked from `Crypto.validate_payload_size!` and the source only.

### Mobile signup entry — 2026-10-04

Local Discourse reference HEAD was rechecked at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`; no backend file was changed. `config/routes.rb` maps `/u.json` to `users#create` and `/u/activate-account/:token` to account activation. `UsersController#create`, `UserActivator`, `UsersController#perform_account_activation`, the signup route/controller, and `spec/requests/users_controller_spec.rb` show the required fields, creation response and email activation path. Source review establishes the contract, not deployment success.

On iPhone 17 Pro / iOS 26.1 Simulator, Fomio's `ASWebAuthenticationSession` opened the deployed Discourse login page after local sign-out. Its browser cookie separately retained a `FomioTester01` login, so the test also signed out that browser session; local sign-out alone did not make the authorization page a guest session. The guest page exposed **Sign Up**. Tapping it displayed mobile EMAIL, USERNAME and PASSWORD fields. The user-supplied fresh email was entered on that mobile form and the page displayed “We will email you to confirm.” This verifies mobile signup entry and initial email validation only. Account submission, verification email, activation, return to authorization, new per-user key and app member identity are pending the user's password/terms and inbox steps. Do not treat the earlier desktop browser signup check as mobile evidence.


## Native category/topic implementation — 2026-10-06

Reference HEAD rechecked: `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. Backend remains unchanged. `CategoryDTO` now retains the optional identity fields/uploads listed above, description excerpt and `topic_url`. The directory and composer use each category's own identity; the header optionally prefers the appropriate light/dark logo. Known Font Awesome names have an explicit SF Symbol mapping and a small supported emoji mapping. Unknown/custom identifiers, absent/failed assets use a category-color square; no category initials or parent identity are invented. Public HTTPS assets use a separate unauthenticated image request; secure category media is not established.

The adapter requests `GET /site.json` and maps `default_light_color_scheme` / `default_dark_color_scheme` resolved `colors[].name/hex`. Route/controller/Guardian and request/serializer-spec trace remain as recorded above. Native roles map primary→text, secondary→surface, tertiary→actions, danger/success/love→matching state roles; muted text, borders and fills derive from those roles. Missing/malformed colors use the existing native fallback palette. Theme CSS/JS is not executed. **Site default schemes are supported; a member's selected scheme/theme precedence is unresolved and is not claimed implemented.** A failed theme fetch retains the current palette and records `themeError`; a first-load failure uses fallback.

`TopicDTO` now retains viewer-resolved `pinned`, `bumped_at` and `archived`; `ListableTopicSerializer` supplies pinned/activity, `TopicViewSerializer` supplies archived. `RootsDTO` / `ContextDTO` retain `effective_sort`; initial page metadata is reused for later roots. `NestedReplies::Sort` confirms new=descending creation time, old=ascending post number. Native labels describe the effective order only when returned; requests continue to ask for new. Closed/archived labels do not override `details.can_create_post`. No new sorting UI or reading/realtime side effects were added.

Status: source reviewed; sanitized Swift adapter tests and native fixture verification recorded in [implementation status](implementation-status.md). New fields and `/site.json` scheme selection have not been verified against deployed member/guest responses in this implementation turn. Existing categories request still has the documented lazy-catalog/completeness limitation. One subcategory level is the user-confirmed presentation scope; deeper backend categories are not reparented. Background fields are retained for future safe rendering but are not composited behind native text. Header `text_color` is retained; markers use the configured category color against a tinted tile, rather than assuming a readable arbitrary backend text/background pair.

## Live category/topic API validation — 2026-10-06

Backend reference HEAD was rechecked at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`; no backend changes. These findings supersede the unverified-deployment and catalog-limit status in the preceding implementation section.

- **Site identity: live guest and member verified.** The configured `https://meta.fomio.app/site.json` returns the resolved Fomio default light scheme (primary `1b1a1f`, secondary `ffffff`, tertiary `5b3fd6`). `default_dark_color_scheme` is null, so the native dark fallback is intentional. Categories return their own identity fields. Selected member scheme/theme precedence, arbitrary custom icons/emoji, protected media, CSS overrides and realtime theme changes remain unresolved.
- **Directory: live guest/member decoding verified; paging source/spec and simulated transport verified.** The guest directory returns 26 categories (11 roots and 15 immediate children), matching the secured site catalog except intentionally omitted Uncategorized. `CategoryList#prune_empty` accounts for that exclusion. Root page requests are 1-based; nonpaged page 2 is empty. `CategoriesController#fetch_category_list`, `CategoryList` and categories request specs confirm `parent_category_id` child scoping and lazy previews. The native adapter now loads root pages until no progress, then fetches scoped child pages where secured IDs/counts exceed the preview; IDs are deduplicated, cancellation is respected, requests are bounded, and failure does not publish a partial catalog. The current deployment did not require lazy child completion; that path is tested with synthetic responses. Catalog changes during multiple requests are not an atomic snapshot guarantee.
- **Feeds and exact topics: live guest verified.** Every visible root's category feed was decoded and its actual root/child category retained. Latest pagination, three topic root payloads, exact OP/reply contexts, children, search-hit targets and a missing-topic error were exercised through the native adapter. Member profile, Saved, notifications, site theme, categories and a topic read were exercised with the existing per-user Keychain credential. These checks do not establish the permissions of other trust levels or restricted groups.
- **Temporary writes: user-authorized and live verified.** The approved Experiments & Ideas category (54, parent 45) was verified by ID/name/parent and creation permission before posting. A temporary topic plus two labeled replies verified OP/category/author, exact reply numbers, nested parent, ancestor chain, children, quote publication, the returned own-post Like permission and Save/Unsave. Topic deletion used only the exact returned ID; guest readback confirmed it unavailable afterward. The first run exposed the Saved decoder bug and deleted its topic; its remaining test bookmark was removed during recovery. The corrected round trip also deleted its topic and bookmark. No permanent deletion, unrelated content changes, uploads or administrator API key were used.
- **Saved response fix: source/spec and live verified.** `UsersController#bookmarks` returns `{bookmarks: []}` for empty results but `UserBookmarkListSerializer` wraps nonempty results under `user_bookmark_list`. Users request specs explicitly assert that root. The native decoder now handles both shapes, retaining `more_bookmarks_url`, bookmark ID, topic ID and `linked_post_number`. A sanitized regression covers nonempty pagination and flat empty results. Plugin bookmark types without topic destinations remain omitted.
- **Cleanup permission constraint: source reviewed and member preflight verified.** `TopicGuardian#can_delete_own_topic?` requires at most one post and creation within 24 hours. Regular authors therefore cannot immediately delete a replied-to topic. The write integration check requires current-session moderator/admin authority before creating this test content; it uses the member's per-user key. `TopicsController#destroy`, post destruction and Guardian checks were reviewed. A future nonstaff test requires a separately authorized cleanup plan.
- **Rate limiting: live observed.** A closely spaced rerun returned 429 before publication; it was recorded as `rateLimited`, not empty content or successful posting. A later spaced run passed. No automatic posting retry was introduced.

Integration tests are opt-in. `FOMIO_LIVE_READ_TESTS=1` enables guest/member reads; `FOMIO_LIVE_WRITE_TESTS=1` enables the explicitly approved temporary-content test. Ordinary runs skip live tests. Write authorization must be obtained for each future task; an environment flag is not authorization. `FOMIO_PREVIOUS_TEST_TOPIC_ID` is only for cleanup of the exact ID recorded by an earlier approved run, never a title/search match. No credentials or raw account payloads are stored in this documentation.

## Final native audit — 2026-10-07

Backend reference HEAD freshly checked and unchanged at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`; no backend changes. Live anonymous adapter checks, stored-member read checks and native category → child → About → topic navigation passed again. This audit made no live member mutations and did not repeat yesterday's approved temporary write tests. Source inspection confirmed the Like response's PostSerializer includes `topic_id`; no adapter contract change was needed.

Two local diagnostic probes exposed cache invalidation gaps: a successful refresh retained a removed child in an expanded branch, and an HTTP 403 refresh retained the old topic page/text and its earlier reply permission. The latter is simulated transport evidence, not a deployed revocation test. Server authorization is still enforced; native display currently retains stale content/controls. These are open client fixes. See [final audit findings and exact evidence](validation/2026-10-07-final-audit/README.md). Existing deployed revocation/trust-level/upload/theme-preference assumptions remain unresolved.

## Audit cache corrections — 2026-10-07

The native refresh defects recorded above are now corrected: successful refresh replaces reply caches and refetches reachable expanded branches; 401/403/404 remove the previously visible topic/controls, while offline refresh retains content. Late results from an older cache generation do not repopulate a replaced cache. Sanitized transport regressions cover all three status codes; fixture regressions cover deleted children, empty branches and offline retention. These are local client-state verifications, not a new deployed revocation experiment or API contract change. Backend HEAD was rechecked and remains `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`; no backend edits or live mutations. [Fixes and final test evidence](validation/2026-10-07-audit-fixes/README.md).
