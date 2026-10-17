# Discourse API reference

## Reporting & Safety stage-2 contract confirmation — 2026-10-17

> **Current status (2026-10-18):** see [current status](design/reporting-safety/stage-gates.md#current-status--2026-10-18). Local backend checks passed, now also at deployed revision `821e9e2f`. Deployed member round trips were **waived by the user, not passed**. Live plugin effects, actual moderator delivery and issued-key grants remain release items. Native is implemented. The dated entries below are history; their “paused” and “blocked” statements were superseded on 2026-10-17.

The approved Reporting & Safety designs (approved 2026-10-17) were handed to implementation. Per the user's decision on 2026-10-17, **native implementation was paused** (superseded later that day, after the user waived the deployed round trips) until controlled-account live validation runs. `ignore_allowed_groups` and `flag_post_allowed_groups` **stay unchanged**. This pass was read only: no site setting, report, Ignore, preference, PM or backend change. No credentials were used. No account was created.

**Revisions.** Reference checkout `/Volumes/Develop/Projects/Dicourse` is still at HEAD `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2` (2026-10-02). Its pre-existing untracked file was not used. **Deployed read verified:** guest HTML `generator` meta on `https://meta.fomio.app` reports `Discourse 2026.10.0-latest`, commit `28529a6d63f99d8dea00017e69981ab42d4700fc` (2026-10-16). That commit is present in the reference object store and is **newer** than reference HEAD: `git rev-list 28529a6d..HEAD` is empty. Contracts below were read at the deployed commit with `git show <rev>:<path>`. The checkout was not moved. A diff of the safety files between the two revisions (post actions controller/creator, Guardian/PostGuardian, users controller, IgnoredUser, current-user/user/user-card/post/site serializers, TopicView, nested replies) found only one relevant change: silenced users may now flag **Illegal** when `allow_all_users_to_flag_illegal_content` is enabled. Earlier `d4296c5` findings for these contracts otherwise still hold at the deployed revision.

### Deployed reads (guest, no authentication)

| Read | Result |
| --- | --- |
| `GET /site.json` `post_action_types` | In server order: `notify_user` 6 (“Send @%{username} a message”, require_message, **messages the author, not a moderator report; exclude from Report**), `off_topic` 3, `inappropriate` 4, `spam` 8, `illegal` 10 (require_message), `notify_moderators` 7 “Something Else” (require_message), `like` 2 (not a flag). All flags `enabled: true`. Descriptions contain HTML with relative links (`/guidelines`); render as sanitized text/links. `applies_to` includes `Chat::Message`; this is not evidence that chat is enabled for native use. |
| `GET /site.json` `topic_flag_types` | 4, 8, 10, 7. Off-topic is post-only. `notify_moderators` has an empty topic description. |
| Policy resources | `site.json` `tos_url: /tos`, `privacy_policy_url: /privacy`. `/guidelines`, `/tos`, `/privacy` return 200 HTML pages. Whether their content is final policy text was **not** reviewed. |
| Contact | `GET /about.json` publishes a `contact_email` and a `contact_url`. The `contact_url` holds an email address, not a URL, so a client must not treat it as a link. Whether these are the intended, staffed support destination is an **operations decision, unverified**. No address is recorded or embedded here. |
| Filtering hints | `site.json` `censored_regexp`, `watched_words_replace` and `watched_words_link` are empty for guests. This is **not** evidence about block/require-approval watched words, link limits or upload rules. Those need an admin read. |

### Source contracts at the deployed revision

| Contract | Evidence (deployed rev) | Finding / native consequence |
| --- | --- | --- |
| Report submit | `PostActionsController#create`; `PostActionCreator#perform` | `POST /post_actions.json` with `id` (post ID), `post_action_type_id`, optional `message`. For a whole discussion, send `id` = **topic ID** with `flag_topic=true`; the controller resolves the first post. Member clients must not send `take_action`, `is_warning` or `queue_for_review`. Success renders the reloaded **post JSON**: confirmation means a 2xx response whose post payload decodes. There is no receipt ID. |
| Error mapping | `ApplicationController#render_json_error/#status_code`; rate-limit rescue | Not permitted → **403**, error text either `action_already_performed` or `invalid_access` (localized; don't string-match; refetch instead). Already handled (`reviewables.already_handled`) and PM-creator errors → **422**. `PostAction.limit_action!` allows 4 per post+type per minute → **429**, with `Retry-After` and `extras.wait_seconds`. Missing or invisible post → **404**. `RecordNotUnique` is treated as success: a duplicate submit returns the existing action rather than failing. |
| Required message | `PostActionCreator`; `config/site_settings.yml` `min_personal_message_post_length` (client: true, default 10) | **The server does not reject a missing message for `require_message` types.** It creates the flag without one. With a message, Illegal/Spam/Something Else also create a moderators PM whose body wraps the message in a template, so the PM length check doesn't enforce a minimum on the member's text. The client must require non-empty details for `require_message` reasons. The configured minimum is not exposed to the API without preload data, so it is **unverified**. Don't hardcode the sample 10. |
| Eligibility | `PostGuardian#post_can_act?`; `PostSerializer#actions_summary`; `TopicViewDetailsSerializer#include_can_flag_topic?` | Per-type `can_act` in `actions_summary`. Once **any** flag type is `acted`, `can_act` is removed from every flag type (`already_did_flagging`), so `acted` on any flag type = “Already reported”. Flags are denied on hidden posts, for silenced users (Illegal exception above) and on staff authors when `allow_flagging_staff` is off. **Flagging requires `flag_post_allowed_groups`. The source default is admins, moderators, TL1, so TL0 new members can't report** except Illegal when `allow_all_users_to_flag_illegal_content` is on. The deployed values of these settings are **unread**. Topic `details.can_flag_topic` is emitted only when the opening post has any `can_act`. |
| Ignored replies | `NestedReplies::PostTreeSerializer#serialize_post` | Ignored non-OP replies come back with `cooked` blank, `raw` null and `actions_summary: []`. **Reporting an ignored reply can't use the tree payload.** The client must fetch that post (for example `GET /posts/:id.json`) to obtain fresh `can_act` state. Live member shape is unverified. |
| Ignore write | `UsersController#notification_level` | `PUT /u/:username/notification_level.json` with `notification_level=ignore` and `expiring_at` (parsed; required), `mute`, or `normal`. An existing Ignore row has its expiry updated. Ignore deletes Mute; `normal` deletes both. Errors use `ignore_error`; denial raises `InvalidAccess` (403). Never send `acting_user_id`: non-staff use raises 403. |
| Ignore eligibility/targets | `Guardian#can_ignore_users?/#can_ignore_user?`; `CurrentUserSerializer#can_ignore_users`; `UserCardSerializer#can_ignore_user/#ignored/#muted/moderator/admin` | Staff or `ignore_allowed_groups` (deployed read 2026-10-16: admins, moderators, TL2, unchanged by this pass). Self and all staff targets are excluded. The user card/profile serializer gives target-specific `can_ignore_user`, `ignored` and `muted`. |
| Ignored list | `CurrentUserSerializer#ignored_users`; `UserSerializer#ignored_usernames` | **Usernames only; no `expiring_at` is serialized anywhere inspected.** The design's “duration per row” on Ignored users (I05) can't be shown truthfully from server data. Show the list without per-row duration, or establish a supported contract first. |

### Remaining stage-2 gates (open)

The checklist is in [stage gates](design/reporting-safety/stage-gates.md#stage-2-status--2026-10-17). In summary:

1. Controlled accounts are required: TL0, TL1, TL2, plus a staff target and an ordinary target author, all disposable and approved. Exercise live member flag create/already/denied/422/429, topic flagging and the ignored-reply refetch. Confirm moderator queue receipt and handling, with cleanup.
2. Admin reads of `flag_post_allowed_groups`, `allow_all_users_to_flag_illegal_content`, `allow_flagging_staff`, `max_flags_per_day`, `min_personal_message_post_length`, watched words, link/upload limits and approval settings.
3. Ignore eligibility decision. `logged_in_users` stays proposed and not applied. Until it changes, TL0/TL1 accounts without another eligible group get the truthful “Ignore unavailable” state.
4. Ignore Forever / finite / normal round trips on two clients, with PM and notification suppression. Confirm that per-row expiry is unavailable.
5. User API key grants for the `read,write,notifications,session_info` scopes on these write paths.
6. Operations: staffed moderator owner and response target, confirmation that the published contact is the support destination, and review of policy page content.

*Historical, superseded 2026-10-17:* native implementation was to stay paused until gates 1–5 had live evidence. The design intent and these contracts are the implementation basis. The browser prototype's runtime is not.

### Controlled-account backend checks — 2026-10-17

The user authorized agent-created disposable accounts and backend checks. Live eligibility settings stay unchanged.

**Where accounts could be created.** Agent safety policy does not permit creating accounts or signing in with passwords on the deployed host `meta.fomio.app`. Disposable accounts were therefore created only in an **isolated local Discourse test database at the deployed revision** `28529a6d`. The source was extracted with `git archive` into the session scratchpad; the reference checkout stayed at `d4296c5` and clean. The JS dependencies (`pnpm install --frozen-lockfile`) were installed only in that scratch copy. The locked `raindrops` git gem was missing for this revision, so it was added to the machine's Ruby gems by `bundle install`. Database name: `discourse_test_fomio_safety_28529a6`. `LOAD_PLUGINS=0`, so plugins were not exercised. Accounts were fabricated records (admin, moderator, TL0, TL1, TL2, a second TL2 reporter, a TL1 target author) with controlled topic, posts and a staff-authored post. Every member request used a fabricated **per-user API key with the native scopes `read,write,notifications,session_info`**. No password, admin API key or live credential was used. Nothing was recorded or printed beyond the fixed fictional strings in the spec.

**Evidence:** [`fomio_safety_contract_spec.rb`](validation/2026-10-17-safety-backend/fomio_safety_contract_spec.rb), **18 examples, 0 failures**, in two random orders (seeds 44261, 57069). At the same revision the upstream specs also pass:
- `post_actions_controller_spec`, `post_action_creator_spec`, `nested_replies/post_tree_serializer_spec`, `user_comm_screener_spec`, `purge_expired_ignored_users_spec`, `ignored_user_spec`: 118 examples, 0 failures.
- `users_controller_spec` `#notification_level` + `ignore`: 13 examples, 0 failures.

**Status: verified locally at the deployed revision with default settings plus the deployed `ignore_allowed_groups`. Not deployed verification.** Deployed settings, plugins, key grants and staffing may differ.

| Check | Result (local, deployed revision) |
| --- | --- |
| Member flag on a reply | 200 with reloaded post JSON. `acted` set; no flag type keeps `can_act`. A pending `ReviewableFlaggedPost` is created. No receipt ID. |
| TL0 under default `flag_post_allowed_groups` (`1\|2\|11`) | No flag `can_act`; POST → **403**. Illegal is allowed for TL0 only with `allow_all_users_to_flag_illegal_content`. That setting's validator requires a site contact email or an illegal-content report email. |
| Repeat flag by the same member | **403** (already flagged) before the per-post limiter is reached. `acted` remains readable on a fresh `GET /posts/:id.json`. |
| `require_message` reason without a message | **200, accepted with no message** and no moderators PM. Confirms the client must enforce details. With a message, a PM to the `moderators` group is created. |
| Whole discussion | `id`=topic ID + `flag_topic=true` → 200, resolves to the OP, `targets_topic=true`. `details.can_flag_topic` is true for TL2 and absent for TL0. |
| Moderator delivery/handling | Moderator `agree_and_keep` via `/review/:id/perform` → reviewable approved. The reporter **still sees `acted`** after handling. A second reporter's same-type flag → **422** (already handled). |
| Removed post | 404. |
| Rate limit | Daily flag cap (`max_flags_per_day`, enforced via `create_flag`) → **429** with `Retry-After` and `extras.wait_seconds`. The 4/min per-post limiter is not reachable by repeating a flag, because 403 comes first. |
| Ignore eligibility (deployed groups `1\|2\|12`) | TL0/TL1 denied; TL2 allowed. With the proposed `logged_in_users` (5) added **in the test database only**, TL0 is allowed. |
| **Ignore denial status** | **422, not 403.** `notification_level` rescues `InvalidAccess` into `render_json_error("notification_level.ignore_error")`. The same applies to staff target, self target and non-staff `acting_user_id`. No row is written. Native must not treat this as editable validation; refetch the card (`can_ignore_user`, `moderator`/`admin`) to show the truthful state. |
| Account-level persistence | A Forever (1,000-year) expiry is stored. A second key for the same account sees `current_user.ignored_users` (usernames) and `can_ignore_users`; the user card shows `ignored: true`. **No `expiring_at` appears in `session/current.json`.** |
| Ignored reply projection | Nested `/n/` (with `nested_replies_enabled`): ignored reply has `ignored_post_placeholder`, blank cooked and `actions_summary: []`. **The OP body is still returned**, so the client must hide it. A fresh `GET /posts/:id.json` keeps flag `can_act`. |
| Communications | A new PM from the ignored author → 422. A mention by the ignored author creates no notification. |
| Mute/normal | Ignore replaces Mute; `normal` clears both. |
| Finite expiry | Still effective after expiry until `PurgeExpiredIgnoredUsers` runs, then removed. |

**Cleanup.** Every example ran in a rolled-back transaction, so no flags, reviewables, PMs, notifications, Ignore rows or accounts persist. The isolated database `discourse_test_fomio_safety_28529a6` was dropped after the run. The scratch source copy lives only in the session scratchpad. The added `raindrops` gem remains in the local Ruby gems. Nothing was written to `meta.fomio.app`.

**Blocked, not run (not passes).** Items 2–3 were later **waived by the user, not passed**; they remain release items:
1. ~~Live eligibility settings unread.~~ **Resolved 2026-10-17:** read-only in the built-in browser after the user signed in themselves (see below).
2. **Deployed member round trips.** Live TL0/TL1/TL2 report/Ignore/denied/persistence checks need accounts created and signed in by a person. The checklist is in [stage gates](design/reporting-safety/stage-gates.md#controlled-account-validation-checklist).
3. **Deployed moderator delivery** to the real review queue and real staffing.
4. Plugins (`LOAD_PLUGINS=0`), push/email delivery, existing/group PMs and chat were not exercised.

**Deployed settings read — 2026-10-17 (read only, admin session signed in by the user, nothing changed).** Read via `GET /admin/site_settings.json` and `GET /admin/customize/watched_words.json` in the built-in browser. Email values are recorded only as set or empty.

| Setting | Deployed value (default) | Consequence |
| --- | --- | --- |
| `flag_post_allowed_groups` | `1\|2\|11` admins, moderators, TL1 (default) | **TL0 new members can't report Off-Topic, Inappropriate, Spam or Something Else.** |
| `allow_all_users_to_flag_illegal_content` | **true** (default false) | TL0 (and silenced users) **can** report Illegal, which requires details. The native TL0 sheet will truthfully list only Illegal. |
| `email_address_to_report_illegal_content` / `contact_email` | empty / set | The validator for the setting above is satisfied by the contact email. |
| `allow_flagging_staff` | true (default) | Staff-authored posts are reportable. |
| `max_flags_per_day` / `cooldown_hours_until_reflag` | 20 / 24 (defaults) | Daily cap 429 as verified locally. |
| `min_personal_message_post_length` | 10 (default) | The minimum for details text, if the client mirrors the web client. Not exposed via the API. |
| `ignore_allowed_groups` | `1\|2\|12` admins, moderators, TL2 (default; unchanged) | TL0/TL1 can't Ignore (422). |
| `personal_message_enabled_groups` | `1\|2\|11` (default) | TL0 can't send PMs, and `notify_user` isn't offered to TL0. |
| `user_api_key_allowed_groups` | `1\|2\|0` admins, moderators, **everyone** (default `1\|2\|10`) | All accounts may obtain native per-user keys. |
| `allow_user_api_key_scopes` | default list incl. `read`, `write`, `notifications`, `session_info` | The native requested scopes are allowed. Grants on individual issued keys are not inspected. |
| `nested_replies_enabled` | **true** | The `/n/` ignored-placeholder behavior verified locally applies. |
| `enable_category_group_moderation` | **true** | Moderator PMs and reviewables may also reach category moderator groups. |
| Watched words | **none configured** for any action (block, censor, require_approval, flag, link, replace, silence) | **No pre-publication word filtering.** |
| `approve_post_count` / `approve_unless_allowed_groups` / `approve_new_topics_unless_allowed_groups` | 0 / `1\|2\|10` / `1\|2\|10` (defaults) | No approval queue for ordinary members. P02 is reachable only through other triggers. |
| `newuser_max_links` / `newuser_max_embedded_media` / `newuser_max_attachments` | **0 / 0** / 0 (defaults 2/5/0) | New users can't post links or embedded media: a strict link and media filter. |
| `authorized_extensions` / `max_image_size_kb` | images only / 10240 (defaults) | Upload type and size limits. |
| `auto_silence_fast_typers_on_first_post`, `num_users_to_silence_new_user`, `hide_post_sensitivity` | true, 3, 6 (defaults) | Automatic spam/flag responses are active at defaults. Auto-hide thresholds are not verified live. |
| `must_approve_users` / `default_trust_level` | false / 0 | New accounts start at TL0 without approval, so the TL0 limits above apply to every new member. |

**User decision — 2026-10-17: deployed account round trips waived.** The user judged the deployed-member checks unnecessary. Basis: the deployed revision `28529a6d` matches the locally tested revision; deployed settings were read directly; core flag and Ignore behavior is covered by Discourse's own specs (131 passing at that revision) plus the 18 Fomio contract checks. The deployed TL0/TL1/TL2 round trips are therefore **waived, not passed**. Residual items stay open as release items, to be observed during native live testing with a real member account:
- plugin effects (local runs used `LOAD_PLUGINS=0`);
- delivery and handling in the real review queue, plus moderator staffing;
- grants on issued user API keys;
- existing/group PM and push/email behavior.

**Settings change for approval (not applied).** Native code doesn't need a setting change to work: it shows whatever the server permits. Release coverage for new members does need one. Proposed:
- (a) `ignore_allowed_groups`: add `logged_in_users`, keeping the mandatory admins and moderators. Verified locally to make TL0 eligible while keeping self/staff denial.
- (b) `flag_post_allowed_groups` is the default `admins|moderators|trust_level_1`. Proposed: add `logged_in_users` (or `trust_level_0`) so new members can report every reason, not only Illegal. `allow_all_users_to_flag_illegal_content` is already on. This widens moderator queue volume and spam-flag abuse exposure, so pair it with staffing.
- (c) Filtering: no watched words are configured. Decide whether block or require-approval lists are needed for Guideline 1.2 "filtering" evidence. New-user link and media limits (0/0) already apply.

Neither change is applied. Each needs explicit approval and a before/after record.

### Native adapter status — 2026-10-17

`Fomio/Data/SafetyService.swift` implements the contracts above. Its request and response shapes are pinned by `FomioTests/SafetyContractTests.swift` with stubbed transport: **stub evidence, not a live run**. Live behavior with a real member key on `meta.fomio.app` has not been exercised by the app. Plugin effects, real review-queue delivery and issued-key scopes remain open release items under the user's waiver.

## Ignore/blocking assessment — 2026-10-16

[Full assessment and evidence matrix](ignore-blocking-assessment.md). Backend HEAD rechecked at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`; reference remained unchanged. Routes/controller/serializers/Guardian, communications and hiding paths plus related spec assertions were reviewed; specs were not executed.

**Deployed read verified:** existing authenticated browser showed `ignore_allowed_groups = admins, moderators, trust_level_2` at the site’s admin settings page. The selector offers `logged_in_users` and `trust_level_0`; no selection or setting was changed. Combined with source `Guardian#can_ignore_users?`, ordinary TL0/TL1 users without another eligible membership cannot Ignore under this configuration. No fresh member write/denial was exercised; this is setting evidence plus source behavior, not a live TL0 API test.

**New source facts:** the web Ignore modal offers **Forever**, encoded by `timeShortcuts.forever()` → `thousandYears()` as a timestamp roughly 1,000 years ahead. Thus required `expiring_at` does not force a short-duration feature. Expired rows are purged daily; several read/communication queries rely on row removal rather than inline expiry checks. Core rejects ignored nonstaff senders’ new PMs and screens new post-derived notifications/invites, with staff exemptions. Flat/nested reply suppression preserves OP content in API payloads; the web client handles ignored OP/embedded content and attributed quotes itself. Ignore is not a public-read/reply authorization boundary. Normal/Mute/Ignore transitions clear the other preference as described below.

**Decision:** candidate server foundation only. Proposed configuration is to add `logged_in_users` for member eligibility, then verify controlled member Ignore/Forever/unignore and communication/content coverage before implementation. Native must project authoritative account preferences across OP/quotes and other exposed surfaces. Staff exceptions, existing/group PM behavior, missing author data in some lists, deployed source parity and actual key grants remain release gates. No claim of Apple acceptance, reciprocal invisibility, service ban, complete chat coverage or live mutation success. No configuration/backend/app code changed.

## Reporting and user protection source review — 2026-10-16

Fresh backend HEAD: `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. Reference checkout `/Volumes/Develop/Projects/Dicourse` was read only; unrelated untracked `docs/sidebar-outlet-discovery.md` was not used. Status: **source contract reviewed; deployment unverified for these actions**. Specs below were inspected, not executed. No live report, preference write, backend change or settings change occurred. [Proposed IA maps](reporting-safety-ia.md).

| Contract | Inspected evidence | Findings and limits |
| --- | --- | --- |
| Post/reply report | `config/routes.rb` post_actions; `PostActionsController#create`; `lib/post_action_creator.rb`; `lib/guardian/post_guardian.rb`; `spec/requests/post_actions_controller_spec.rb`; `spec/lib/post_action_creator_spec.rb` | `POST /post_actions.json` with `id` = post ID, `post_action_type_id`, and `message` for supported actions. Login and visibility required. Creator rechecks permissions, duplicates/handled reports and rate limits. Success serializes the updated post; it is not a standalone receipt. Member clients must omit staff controls (`take_action`, `is_warning`, `queue_for_review`). Specs cover login/visibility denial, staff-warning restrictions, reviewable creation and repeat-flag behavior. Live settings, limits and receipt reconciliation remain unverified. |
| Discussion report | Same controller `fetch_post_from_params`; `SiteSerializer#topic_flag_types`; `TopicViewDetailsSerializer#include_can_flag_topic?` | For topic flagging the `id` parameter is the **topic ID** and `flag_topic` uses the string `"true"` for the creator path; controller resolves the first post. Do not mix post and topic IDs. Confirm actual topic action-summary/capability payload and deployed eligibility before exposing. |
| Reason catalog and eligibility | `SiteSerializer#post_action_types/#topic_flag_types`; `FlagSerializer`; `PostActionTypeSerializer`; `PostSerializer#actions_summary`; `PostGuardian#post_can_act?` | Site catalogs include IDs, names/descriptions, `is_flag`, `enabled`, `require_message`, `applies_to` (and order in catalog). Post actions expose per-reason `can_act`, `acted`, conditional `can_undo`. Disabled reasons, silenced/anonymous users, hidden posts, staff-target settings and allowed groups constrain availability. Do not hardcode reason IDs or assume all members can report. Distinguish notify-author/message actions from moderator flags. Custom reason/localization shape needs live verification. |
| Moderator delivery | `PostActionCreator#perform/#create_reviewable`; service specs for flags/reviewables and non-human users | Flagging can create `ReviewableFlaggedPost` with moderator review eligibility and a score. Bot posts can skip reviewable creation; other action types can create messages instead. A generic successful post action is not proof that a moderator ticket was delivered. Staff response process, queue access and actual routing need approved live verification. |
| Ignore/Mute/restore | `config/routes.rb` username notification_level route; `UsersController#notification_level`; `Guardian#can_ignore_user?/#can_ignore_users?/#can_mute_user?`; `UserCardSerializer`; `UserSerializer`; `spec/requests/users_controller_spec.rb` notification_level examples | `PUT /u/:username/notification_level.json` accepts `ignore` plus `expiring_at`, `mute`, or `normal`. Ignore is group-gated; self/staff targets excluded. Mute has separate trust/staff eligibility and removes Ignore; Ignore removes Mute; normal clears both. User card emits target-level `can_ignore_user`/`can_mute_user`; full user serializer has self-only preference fields including `ignored_usernames` and `can_ignore_users`. Specs cover denied staff targets, persistence, expiry and normal/mute transitions. No permanent block contract, comprehensive interaction coverage, cross-device behavior or universal new-member eligibility established. |
| Per-user scope | `app/models/user_api_key_scope.rb` | Core `write` covers POST/PUT and other listed methods; `read` covers GET. Existing deployed key grants/allowed parameters must be checked. Do not add administrator credentials or assume a new dedicated flag scope exists. |

**Open gates:** current deployed revision/catalog and custom flags; new-member eligibility; actual filtering/approval coverage for text/media; safe support destinations/contact; approved member report and moderator handling round trip; precise Ignore interaction effects, duration and restoration; profile/bio/avatar report route; action-state reconciliation after timeout/handling; effective per-user key scopes. Existing live read/posting evidence elsewhere does not verify these moderation contracts. Core Ignore/Mute must not be relabeled Block on source evidence alone. No enabled plugin list or new deployment resources are assumed.

## Topic list media and card metadata — 2026-10-15

Backend reference HEAD freshly rechecked at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2` (commit date 2026-10-02); read only, no backend changes, server startup or request-spec execution.

| Field | Source evidence | Native mapping | Status |
| --- | --- | --- | --- |
| `image_url` | `ListableTopicSerializer` attribute → `Topic#image_url(enqueue_if_missing: true)`: the 1024×1024 share thumbnail's optimized URL, else `image_upload.url`, passed through `UrlHelper.cook_url` (absolute; secure-upload proxy when `secure_uploads` applies). Required key, `string|null`, in `spec/requests/api/schemas/json/category_topics_response.json`. Topic visibility is enforced by `ListController`/`TopicQuery` and `Guardian` before serialization; the image belongs to a topic the viewer may list. | `TopicDTO.imageUrl` → `DiscussionSummary.imageURL` through `PublicMedia.url`: HTTPS absolute, protocol-relative or site-relative only; no embedded credentials; never sent with user keys (plain `AsyncImage`). Failed loads remove the media slot. Live mode never shows bundled fixture photos. | **Source reviewed; deployed guest verified.** Anonymous `GET https://meta.fomio.app/latest.json` (2026-10-15) returned 30 topics; 24 have absolute `https://meta.fomio.app/uploads/default/{optimized,original}/…` values, 6 are `null`. Member responses, secure/login-required media, CDN hosts and category-feed media were not separately verified. |
| `unicode_title` | `ListableTopicSerializer#include_unicode_title?` (title matches `:shortcode:`) → `Emoji.gsub_emoji_to_unicode(title)`. | `DiscussionSummary.title = unicode_title ?? title` for every `TopicDTO` mapping. | **Source reviewed; deployed guest verified**: topic 5 `Welcome to Fomio! :wave:` → `Welcome to Fomio! 👋`. Cooked inline emoji in posts are unchanged. |
| `thumbnails` | Same serializer; included only when theme or plugin `topic_thumbnail_sizes` are registered. | Not used. | Absent from the deployed guest response (no registered sizes observed). Not inferred. |
| Original author | `posters[]` with `description` containing "Original Poster" + top-level `users[]` (existing mapping). `last_poster_username` is a different person. | `author`; empty when no Original Poster/user match. Last poster is never substituted. | Unchanged mapping; adapter unit test added. |
| Activity | `bumped_at` (existing mapping). | Labeled "Active … ago"; not creation age. | Unchanged. |
| Reply count | `reply_count`, else `posts_count - 1`. | Zero shown as "No replies yet". | Unchanged. |

The deployed response observed above showed `reply_count` 0 on every topic and only topic 5 pinned; it is evidence of field shape, not of community activity. No credentials, administrator keys or site settings were used or changed.

## Native consolidated categories — 2026-10-08

Build iOS Apps / XcodeBuildMCP live anonymous contract verification establishes the existing native adapter returns 11 roots and 9 children after consolidation, with all six retired IDs absent, General's two children and Fomio's seven children intact. All returned icon identifiers now map to validated available SF Symbols; colors decode and Introductions uses the corrected display name. Native directory and filtered child → About → topic navigation pass on iPhone/iOS 26.1 with live data. No endpoint or permission contract changed; backend source HEAD rechecked at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. [Results, captures and practical limits](validation/2026-10-08-native-categories/README.md).

## Category hierarchy consolidation — 2026-10-08

User approved consolidation of General children 50/51/52/53 into root 4, Fomio child 49 into root 45, and Off-topic child 34 into root 9. Fresh source HEAD remains `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. Deployed browser feeds show only their About topics, no regular discussions; all six category editors expose enabled Delete actions and public everyone see/reply/create permissions. `CategoriesController#destroy` calls `guardian.ensure_can_delete!` then hard-destroys the category. `CategoryGuardian#can_delete_category?` requires edit authority, nonpositive regular-topic count, no children, and excludes Uncategorized. Request specs cover anonymous/nonstaff denial and successful count reduction. `Category#trash_category_definition` trashes the About topic after category destruction. Source inspected, specs not run.

After the user's action-time confirmation (“go ahead”), all six category records were deleted through their enabled Settings actions and confirmation dialogs. The authenticated directory now contains **11 public roots and 9 children**, plus unchanged private Staff. General retains Interesting Finds and Introductions; Fomio retains seven children; Off-topic Discussions has no children. All six exact canonical URL permalinks and Random's legacy alias were opened in the browser and resolved to the intended parent URLs with matching latest-topic headings. No regular discussions required migration. Native stale-category/deep-link handling and arbitrary URL suffix redirects remain unverified. [Evidence and exact mapping](validation/2026-10-08-category-hierarchy/README.md).

## Topic-card swipe Save review — 2026-10-08

Source HEAD rechecked: `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. Source review only; no new deployed calls or backend changes. The earlier live Post Save/Unsave evidence remains separate from proposed feed and Topic-bookmark behavior.

**Goal:** Assess a topic-card Save shortcut without conflating topic and post bookmark targets.

**Entry Point:** `config/routes.rb` resources `bookmarks`; POST `/bookmarks.json`, DELETE `/bookmarks/:id.json`; `BookmarksController#create/#destroy`.

**Client Trigger:** Proposed native swipe reveal followed by tap. Existing `Fomio/Data/DiscourseService.swift#bookmark` uses Post ID and exact bookmark ID; `DiscussionSummary` does not retain that identity/state.

**Server Path:** `BookmarksController` → `BookmarkManager#create_for/#destroy` → registered `PostBookmarkable` or `TopicBookmarkable`; their validation and after-create/destroy callbacks govern access and topic-user state.

**Data Map:** Bookmark model schema annotation/associations: `bookmarks.user_id/bookmarkable_type/bookmarkable_id`, unique user/type/target. `TopicPostBookmarkableHelper#sync_topic_user_bookmarked` calls `TopicUser.change` with whether any bookmark exists in that topic. This aggregate is not the identity of the opening-post bookmark.

**Permissions:** Controller requires login; creation rate-limits with `max_bookmarks_per_day`. Post target checks Guardian visibility of topic/post; Topic target checks first-post visibility. Manager's exact-ID removal checks edit access to that bookmark. Request specs reject another user's bookmark removal.

**Async Side Effects:** Reminder support is separate (`BookmarkManager` references `Jobs::BookmarkReminderNotifications`); a quick Save should not silently add a reminder. Bookmarkable cleanup paths enqueue `sync_topic_user_bookmarked`; cleanup is distinct from the normal swipe operation.

**Realtime Side Effects:** Bookmarkable callbacks sync TopicUser through `TopicUser.change`; no direct MessageBus publish was found in these inspected callbacks. Broader indirect effects are not exhaustively verified; native list/Saved reconciliation needs explicit implementation.

**Serializer/JSON Contract:** Create returns success plus bookmark `id`; destroy returns `topic_bookmarked` metadata. `ListableTopicSerializer#bookmarked` is viewer topic state; `TopicListItemSerializer#include_first_post_id?` is conditional on theme/plugin OP-like serialization. Do not assume the OP ID is always present or use a topic ID as a Post ID. Source supports Topic bookmarks, but deploying them from this native feed is not yet validated.

**Tests:** `spec/requests/bookmarks_controller_spec.rb`: rate-limit 429, duplicate Post/Topic target 400, hidden Topic OP 403, exact-ID deletion, aggregate flag remains true while other bookmarks exist, other-user removal denied. Reviewed assertions; tests not executed for this advisory task.

**Safest Extension Plan:** Native gesture/presentation over existing APIs requires no backend extension. For a web counterpart, assess Theme component presentation first. Use a Plugin only if a verified missing contract needs additional fields; Core patch has no established justification. Initially resolve the OP without read-tracking side effects and reuse exact Post Save behavior, or separately validate Topic bookmark semantics. Never bulk-remove discussion bookmarks for a card Unsave.

**Verification Steps:**

```sh
rg -n 'resources :bookmarks' /Volumes/Develop/Projects/Dicourse/config/routes.rb
rg -n 'validate_before_create|bookmark_metadata|after_create' /Volumes/Develop/Projects/Dicourse/app/services/{post,topic}_bookmarkable.rb
rg -n 'rate limits creates|already has bookmarked|does not belong' /Volumes/Develop/Projects/Dicourse/spec/requests/bookmarks_controller_spec.rb
```

Design recommendation (not accepted implementation): one trailing-edge Save reveal in both Compact and Cards; require tap, no full-swipe execution, retain row/order, provide non-gesture access and accessible action, honest pending/failure state. Unsave requires exact target/bookmark identity. Like, mute, mark-read/unread, dismiss and delete remain outside this recommendation.

## Category identity administration review — 2026-10-08

**Later application in this task:** user authorized the proposed edits and established a signed-in category-management session. All 26 public categories now have saved native Discourse icon/color identities and descriptions, plus four display-name corrections. Reloaded directory DOM readback matched all 26 IDs/names/icons/colors; badge text is `FFFFFF`, slugs and parent paths are preserved. Staff was visible only in the authenticated directory and was not edited. The deployed icon picker restricts choices to available sprite icons; 14 meaningful substitutions are recorded in [the applied identity plan](category-identity-plan.md). HTTP 429 responses recovered through cooldown and slower UI edits; no settings were relaxed. Evidence is saved under `docs/validation/2026-10-08-category-identities/`. Backend reference HEAD was freshly rechecked at the same revision. The earlier signed-out/pending-write status below is historical; native mappings, fresh signed-out rendering, dark mode, and updated native API decoding remain pending.

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

Rendering facts established: cooked posts use `<img class="emoji" width="20">` for emoji (for example `/images/emoji/apple/heart.png`). These are now kept inline as their shortcode text instead of becoming photo blocks (`HTMLContent.inlineEmoji`). Topic `title` and `fancy_title` both carry raw shortcodes (`:wave:`). Neither the title nor the inline emoji is converted to Unicode yet. (2026-10-15: titles now use `unicode_title` when sent; see the Topic list media section.)

## Native implementation source review — 2026-10-03

Current reference HEAD: `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`, rechecked before implementation and again during the documentation handoff on 2026-10-03. Only the unrelated untracked `docs/sidebar-outlet-discovery.md` is present. Backend unchanged; no backend server or request specs were run. Deployed verification was blocked pending base URL, version alignment, settings/plugins, callback/scopes and test users; see the 2026-10-04 deployment snapshot above for the resolved items. Test users remain pending. Swift tests use local fictional data, not live-response recordings.

| Contract | Source evidence reviewed | Implementation / verification status |
| --- | --- | --- |
| Browser user key | `user_api_keys_controller.rb` new/create/redirect validation; `app/services/user_api_key/device_auth/crypto.rb`; `user_api_key_scope.rb`; `auth/default_current_user_provider.rb`; `spec/requests/user_api_keys_controller_spec.rb` RSA/padding/callback/group/scopes cases | Contract reviewed for classic browser flow: RSA 2048 OAEP SHA-1, nonce, client ID, encrypted callback payload. Query values must be form-safe: `+` is sent as `%2B` (`LiveConfiguration.url`), covered by `testUserAPIKeyAuthorizationPublicKeySurvivesRailsQueryDecoding`. Pre-consent validation live verified (anonymous 302 to `/login`); consent, callback decryption, Keychain and `session/current.json` are not live verified. |
| Latest/category feeds | Dynamic routes in `config/routes.rb`; `list_controller.rb`; `TopicListSerializer`, `TopicListItemSerializer`, `ListableTopicSerializer`; `Guardian`; list/category request specs | Source-informed adapter uses `topic_list.topics`, user mapping and `more_topics_url`. Feed excerpt/media are optional. 2026-10-15: `image_url` mapped and its deployed guest shape verified (see Topic list media section). Member/secure media and site-specific required fields remain unverified. |
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

## Visual composer/preview boundary — 2026-10-15

The read-only backend reference was rechecked at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. This pass changes the native editor projection and adds a local read-only preview; it introduces no API endpoint, authentication scope, or backend change. Checklist syntax was reviewed in `plugins/checklist/assets/javascripts/lib/discourse-markdown/checklist.js`, `lib/checklist/checkbox.rb`, `plugin.rb` and `config/settings.yml`: `[ ]` / `[x]` are guarded by `checklist_enabled`. Native checkbox edits change draft raw only; they never call the existing-post `/checklist/toggle` endpoint. A new local checklist capability defaults to false and is true only for fixtures; the historical enabled-plugin snapshot above is not promoted to current native/deployed acceptance. No new controller/authorization/request-spec availability claim is made. Existing raw draft/submission ownership remains in place. A local preview is not Discourse-cooked HTML and does not verify plugin-specific rendering, deployed sanitization, or live posting. No new live request/write validation was performed in this pass.
