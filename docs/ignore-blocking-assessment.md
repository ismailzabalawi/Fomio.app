# Discourse Ignore as a blocking foundation

Recorded 2026-10-16 on `codex/discourse-reporting-ia`. Assessment only; no app implementation or backend/settings changes.

## Decision

**Reuse Discourse Ignore as the candidate server-side foundation, but do not ship it as a complete Block feature yet.** It stores a per-account preference, prevents several unwanted communications, and suppresses content. The deployed configuration excludes new members, and some hiding is deliberately implemented by Discourse’s web client rather than by its API. Native must implement equivalent presentation using authoritative account state.

The current site is **not ready for a new-member blocking flow**. The smallest proposed eligibility fix is to add `logged_in_users` to `ignore_allowed_groups`, retaining mandatory admins/moderators. The deployed selector offers this group and `trust_level_0`. Source `User#in_any_groups?` explicitly matches the logged-in pseudogroup; the TL0 automatic group also includes ordinary non-staged members at every trust level. This is a proposed configuration task, not a change performed here. Neither option permits ignoring staff or self.

Do not promise reciprocal invisibility, prevention of public replies, or a service ban. Those are not Ignore’s contract. Apple’s [Guideline 1.2](https://developer.apple.com/app-store/review/guidelines/#user-generated-content), reread in this pass, requires the ability to block abusive users but does not prescribe Ignore or certify this design. The assessment below is engineering evidence, not an App Review acceptance guarantee.

## Evidence status

- Backend HEAD freshly checked: `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`, `/Volumes/Develop/Projects/Dicourse`. Checkout remained unchanged apart from its pre-existing untracked `docs/sidebar-outlet-discovery.md`, which was not used.
- **Deployed setting read verified:** existing authenticated browser at `https://meta.fomio.app/admin/site_settings/category/all_results?filter=ignore_allowed_groups` displays **admins, moderators, trust_level_2**. Expanded selector lists `logged_in_users`, `staff`, `trust_level_0`, `trust_level_1`, `trust_level_3`, `trust_level_4`. Opened then dismissed selector without choosing or saving anything.
- **Source and spec assertions reviewed:** routes, controllers, permission checks, models, serializers, communications, nested/flat rendering, web UI duration/quote behavior and relevant specs. Specs were not run; no backend server/database was started.
- No fresh TL0/TL1/TL2 member API write, Ignore/unignore, PM, notification or content-hiding round trip was performed. Admin settings access does not prove member API access or deployed source parity. Actual deployment version, individual membership overrides and per-user key grants remain unverified.

## Behavior matrix

All behavior below is source-reviewed unless explicitly labeled deployed.

| Concern | Actual contract/evidence | Blocking implication |
| --- | --- | --- |
| New-member eligibility | `Guardian#can_ignore_users?` checks staff or `ignore_allowed_groups`. Source default and deployed selected groups are admins/moderators/TL2. Guardian specs explicitly deny TL0 when only TL1 is allowed and allow qualifying/higher levels. | Ordinary TL0/TL1 accounts without another allowed membership are excluded today. A native label cannot bypass this. |
| Target restrictions | `Guardian#can_ignore_user?` excludes self and all staff. `IgnoredUser.ignored_ids_for` also excludes self/staff when hiding posts. | Staff exception remains even after opening eligibility to all members. Escalation/reporting must remain accessible; evaluate the exception explicitly for release. |
| Persistence and sync | `ignored_users` database rows store user, target, expiry. `CurrentUserSerializer#ignored_users` and `UserSerializer#ignored_usernames` expose usernames; user card exposes `ignored` plus target-specific permission. | Account-wide server state, not a device-only list. Native must refresh on login, foreground/account changes and preference writes; current serializers do not prove live sync latency. |
| Duration | Ignore modal includes `shortcuts.forever()`; `time-shortcut.js` uses `thousandYears()` from `time-utils.js`, roughly now + 1,000 years at the start of that month/day. Model/controller still require `expiring_at`. | The earlier “no permanent contract established” concern is refined: Discourse already has a practical Forever option. Follow its convention rather than inventing a short expiry or auto-renewing. No nullable/permanent database flag exists. |
| Expiry | `PurgeExpiredIgnoredUsers` runs daily and deletes expired rows. `User#ignored_user_ids`, `IgnoredUser.ignored_ids_for`, communications queries and current-user lists generally read rows without checking expiry; digest selection checks expiry explicitly. | Effects can remain until purge in some paths. Do not promise exact-to-the-second expiration. Prefer Forever for a persistent protection flow. |
| New personal messages | `PostCreator` consults `UserCommScreener` for new nonstaff PM topics. Creator specs reject a PM from an ignored sender and allow ignored staff. | Real server-enforced communication protection, with staff exceptions. Do not generalize this to every existing/group PM path without testing. |
| Post notifications | `PostAlerter#create_notification` uses notifier identity and `UserCommScreener`. Quote specs assert ignored senders create no notification. Staff actors bypass screening. | Suppresses new post-derived notifications in this pipeline. No evidence here that old notification records are erased. Mentions/replies/likes need an approved live matrix. |
| Invitations | `Topic#invite` and `create_invite_notification!` check the communications screener. | Another protected direct interaction; staff behavior follows screener exceptions. |
| Flat discussion replies | `TopicView#setup_filtered_posts` removes ignored authors’ posts except post number 1. Specs confirm OP is retained and staff excluded. | Hiding is a reading filter, not loss of access permission. |
| Nested replies | `NestedReplies::PostTreeSerializer` sets `ignored_post_placeholder`, empties cooked/raw/actions for ignored non-OP replies, preserving identity/tree metadata. Serializer/system specs assert placeholder and deliberate reveal. | Existing native placeholder rendering covers this subset. Refresh loaded trees after Ignore; cached bodies must not remain visible. |
| Opening posts and quotes | Nested serializer explicitly keeps OP content. Web `post/cooked-html.gjs` replaces ignored first/embedded post bodies; `post/quoted-content.gjs` checks quoted usernames. | Native needs account-list-based hiding for OPs and attributed quotes. An ignored-reply DTO flag alone leaves gaps. |
| Direct reading/public posting | `Guardian#can_see_post?` checks visibility/types/deletion/hidden state, not Ignore. `can_create_post_in_topic?` is category/PM/spam-rule based, not an ignored-author restriction. Nested web deliberately supports reveal via post retrieval. | Ignore does not revoke public read/reply access, stop the other person reading public content, or ban them. |
| Feeds/search/profiles/Saved | No author-Ignore exclusion was found in inspected `TopicQuery`/search paths. `Topic` has an ignored-author filter specifically in digest selection, not proof of feed filtering. Native search uses result blurbs/authors; profile loads bio and recent topics; Saved renders returned titles. | Audit and explicitly handle each native surface. Do not assume a digest filter covers feeds. Where payloads lack author identity, obtain a supported contract before claiming full suppression. |
| Likes/activity | `PostSerializer`, `PostAction.ignored_user_like_counts_for`, actors controller and `UserAction.filter_ignored_users` filter selected viewer-facing counts/actors/activity. | Presentation suppression, not a prohibition against the ignored person liking public content. |
| Remove/switch protection | `UsersController#notification_level`: `ignore` deletes Mute; `mute` deletes Ignore; `normal` deletes both. | Unignore does not restore a prior mute automatically. Design this deliberately and reconcile the account list. |
| Chat (future boundary) | Chat source has Ignore/communications checks for individual DMs, but the inspected message policy bypasses them for several cases including group channels. | Native chat is deferred. No deployed chat enablement or comprehensive chat-blocking claim is made. |

## Recommended product contract

If member testing succeeds after the eligibility decision, expose a persistent protection action backed by Ignore/Forever. Proposed explanation: “Hide this person’s posts and stop personal messages and post notifications from them.” Qualify actual coverage and staff exceptions in the detailed explanation. Use the Block label only once the app consistently delivers the agreed effects and release review accepts the remaining exceptions. “Ignore user” is the accurate interim research term.

Keep an optional deliberate reveal action separate from removing protection. Keep Report independent and available through the appropriate eligible contract. Do not promise anonymity or that an ignored person cannot infer the preference from rejected communication. There is no new notification-to-target behavior established by this review.

Use the current account’s server preference and target permissions, not a synthetic local block list or admin write. The native preference adapter should omit `acting_user_id` for ordinary self-service requests. Use the existing per-user key with verified write scope and no staff powers.

## Remaining verification before implementation

1. Make the eligibility decision for all signed-in members. Apply the proposed site setting only in a separately authorized configuration step. Leave staff exception explicit.
2. With approved disposable accounts/content, verify TL0 can Ignore an ordinary member after that change, and confirm TL1/TL2, self/staff denial and actual API scopes. Check both browser and native-intended per-user API authentication.
3. Test Forever write → reload on a second client → current-user list/user-card state → ordinary PM rejection → mention/reply/quote notification suppression → normal restore. Include a pre-existing PM and group conversation if available; do not assume new-PM behavior covers them.
4. Capture feed, OP, nested/exact reply, search blurb, quote, profile, Saved and old-notification payloads while ignored. Define native suppression requirements and resolve missing identity data before building the UI.
5. Check that removal of protection restores expected behavior without silently retaining or restoring Mute. Use controlled expired state in a test environment to verify purge behavior; do not alter production clocks or scheduled jobs.

No need to change Discourse core merely to remove the trust-level gate: the deployed group selector already offers the relevant option. Stronger reciprocal restrictions or bans would require a different contract and separately authorized backend work. The immediate next step is the eligibility decision plus controlled member testing, not a SwiftUI Block button.

## Source index

Paths are relative to the backend revision above unless marked native.

- Eligibility: `config/site_settings.yml` (`ignore_allowed_groups`); `lib/guardian.rb`; `app/models/user.rb#in_any_groups?`; `app/models/group.rb`; `spec/lib/guardian_spec.rb`.
- Writes/state: `config/routes.rb` user notification_level; `app/controllers/users_controller.rb#notification_level`; `app/models/ignored_user.rb`; `app/serializers/current_user_serializer.rb`; `user_serializer.rb`; `user_card_serializer.rb`; `spec/requests/users_controller_spec.rb` notification_level examples.
- Duration: `frontend/discourse/app/components/modal/ignore-duration-with-username.gjs`; `frontend/discourse/app/lib/time-shortcut.js`; `time-utils.js`; `app/jobs/scheduled/purge_expired_ignored_users.rb`; `spec/jobs/purge_expired_ignored_users_spec.rb`.
- Communications: `lib/user_comm_screener.rb`; `lib/post_creator.rb`; `app/services/post_alerter.rb`; `app/models/topic.rb`; `spec/lib/post_creator_spec.rb`; `spec/lib/user_comm_screener_spec.rb`; `spec/services/post_alerter_spec.rb`.
- Hiding: `lib/topic_view.rb`; `lib/nested_replies/post_tree_serializer.rb`; `spec/lib/topic_view_spec.rb`; `spec/lib/nested_replies/post_tree_serializer_spec.rb`; `spec/system/nested_ignored_users_spec.rb`; `frontend/discourse/app/components/post/cooked-html.gjs`; `post/quoted-content.gjs`.
- Native gaps: `Fomio/Data/DiscourseService.swift`, `Fomio/Features/DiscussionView.swift`, `Fomio/Features/CookedContent.swift`, `Fomio/Features/AccountViews.swift` in this worktree.
