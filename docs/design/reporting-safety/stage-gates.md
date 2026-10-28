# Design → backend → native gates

## Current status — 2026-10-18

This is the canonical status; dated sections below are decision history.

| Area | Status |
| --- | --- |
| Designs | Approved 2026-10-17. |
| Deployed backend revision | Rechecked 2026-10-18: Discourse `821e9e2f9f94483a3be8d1e077cde0fd94970479` (earlier `28529a6d`). In the 36 commits between them, the only safety-path change is an unrelated user-search parameter. |
| Local backend checks | **Passed** in isolated test databases at `821e9e2f` (and earlier at `28529a6d`), using disposable fabricated TL0/TL1/TL2/target/staff accounts and native-scoped per-user API keys: Fomio contract spec 18/18 (two random orders) plus upstream specs 118/118 and 13/13. Databases dropped; reference checkout unchanged. |
| Deployed settings | Read only on 2026-10-17 via the user's own admin sign-in. **Unchanged.** |
| Deployed member round trips | **Waived by the user (2026-10-17), not passed.** |
| Native | Implemented and committed on `codex/discourse-reporting-ia`. Final run: iPhone 169 tests, 0 failures (5 live-only skipped); iPad safety UI 12/12 ([validation](../../validation/2026-10-17-safety-native/README.md)). |

**Release items (not verified unless stated):**
- Live plugin effects on flags and Ignore.
- **Actual moderator delivery and handling** in the deployed review queue, plus a staffed owner and response target.
- **Issued user API key grants** for the native scopes.
- A first live native run with a real member account.
- Manual VoiceOver pass and physical devices.
- Native-speaker review of the Arabic strings.
- Operations confirmation that the published contact email is the support destination.
- Review of the policy page content.

**Settings changes needing approval (none applied):**
- Add `logged_in_users` to `ignore_allowed_groups`.
- Add `logged_in_users` (or `trust_level_0`) to `flag_post_allowed_groups`.
- Decide on watched words for pre-publication filtering.

Not uploaded to TestFlight; no App Review claim.

Status: proposed handoff for review, 2026-10-16. These are future tasks, not performed changes. The user explicitly stopped native implementation and requested design first.

## 1. Wireframes and mockups

Review the [Claude Design project](https://claude.ai/design/p/24874719-7fed-43f6-b2ba-265fe76556f6) against the [screen inventory](README.md#requested-coverage-inventory). Lock navigation, exact target context, reason/details form, receipt semantics, Ignore naming/effects/duration/reveal/removal, guest/help access and recovery. Inspect adaptations and prototype interactions; generation alone is not validation.

Design acceptance must explicitly separate available behavior from proposals. The desired new-member Ignore path requires a configuration decision. Whole-discussion reporting and profile-abuse escalation need supported deployed contracts. Support resources must be provided rather than invented. Wireframes and mockups must not imply backend success or resolve Apple’s blocking requirement by changing a label.

## 2. Backend configuration and validation

After design acceptance, inspect the deployed version and settings again, recheck the reference checkout revision and use approved accounts/content. Prefer existing supported settings/APIs over core modifications. Any backend change must be scoped to the accepted behavior; keep the reference checkout read only until an authorized implementation task identifies a working backend checkout.

| Workstream | Proposed action or verification | Completion evidence |
| --- | --- | --- |
| Ignore eligibility | Decide whether to add `logged_in_users` to `ignore_allowed_groups`; preserve mandatory staff entries | Reviewed setting change, TL0/TL1/TL2 self-service tests, restricted targets remain honest |
| Report eligibility | Inspect allowed groups and staff/hidden/deleted-target behavior; decide an accessible new-member path | Actual member flags and denied states with exact target/reason identity |
| Reasons | Fetch enabled post/topic catalogs and per-target permissions; confirm custom reasons/message requirements/localization | Sanitized payload evidence, controlled validation cases, no author-message action mislabeled as a report |
| Moderator delivery | Trace an approved test report into the actual moderator workflow and handle it | Confirmed receipt/routing/handling, no invented reporter status API, cleanup recorded |
| Ignore semantics | Exercise finite/Forever, new PM refusal, notifications, list/state refresh and normal restore | Account-level state on two clients; existing/group conversation boundaries documented |
| Reading surfaces | Inspect OP, nested/exact reply, attributed quotes, feeds, search, Saved, profiles and old notifications | Explicit server-vs-client projection contract and missing author identity gaps |
| Filtering | Inspect actual text/link/media controls and approval configuration; exercise rejected/pending outcomes | Content prevented/queued before publication as configured; retained input contract |
| Contact and operations | Provide published guidelines/terms/support destinations; establish moderator ownership and response target | Real usable resources, signed-out availability, owned operational process |
| Auth/security | Verify member scopes and denied/expired responses | Per-user credentials only, no admin credential in native app, no scope assumptions |

Unknown write receipt must never trigger an automatic duplicate. Configuration changes and external writes need concrete reviewable actions and the authorization applicable at that stage. Record before/after values and cleanup; do not perform uncontrolled abuse or report tests against real people.

## 3. Native implementation and acceptance

Only after backend contracts/settings are accepted and verified: extend domain/repository contracts, live DTOs and fixtures, implement shared account preference state, add native views and recovery, then run focused tests and native UI acceptance. Follow the project’s current README, linked guidance and applicable skills at implementation time.

Include state refresh and account isolation; hide OP/quotes using authoritative preferences where APIs preserve bodies; refresh cached trees and relevant lists without conflating Ignore with authorization. Do not silently retain an old account’s ignored list. A preference mutation must be confirmed or reconciled before showing success. Stopping Ignore must not promise that a previous Mute returns.

Validate on iPhone/iPad with VoiceOver, Dynamic Type, keyboard, RTL, background/foreground, session changes, denied/rate-limited/offline/uncertain writes, no automatic sending after sign-in and no duplicate mutations. Browser mockups are design evidence only.

## Stage 2 status — 2026-10-17

Stage 1 is complete: the user approved the designs on 2026-10-17. Stage 2 has started, read-only only. Results are in the [API reference](../../discourse-api-reference.md#reporting--safety-stage-2-contract-confirmation--2026-10-17). User decisions on 2026-10-17:

- **Native implementation paused** until controlled-account live validation runs. *(Superseded later on 2026-10-17: the user waived the deployed round trips and authorized native work.)*
- **Settings unchanged.** `logged_in_users` for `ignore_allowed_groups` remains a proposal. `flag_post_allowed_groups` is to be read, not changed.

### Design reconciliation found during stage 2

| Design item | Contract finding | Required design/implementation adjustment |
| --- | --- | --- |
| I05 “duration per row” | No serializer exposes Ignore `expiring_at`; only usernames | List without per-row duration, unless a supported contract is established |
| R04 sample 10-character minimum | Server doesn't enforce `require_message`; minimum setting not exposed via API | Client requires non-empty details for `require_message` reasons; show server 422 text verbatim; minimum stays a gate |
| R01 report on an ignored reply | Ignored nested replies have empty `actions_summary` | Fetch that post fresh before offering or opening Report |
| R07 Already reported | Any `acted` flag removes `can_act` from all flag types | Derive Already reported from `acted`; refetch after a 403 rather than parsing localized text |
| New-member reporting | `flag_post_allowed_groups` default excludes TL0 | Same truthful-unavailable and support-path treatment as I07a, pending the deployed read |
| H03 / I08 contact | `about.json` publishes contact values; `contact_url` contains an email, not a URL | Read from server at runtime, never embed; ops must confirm it's the staffed destination |
| Menu exclusion of “Message the author” | Catalog id 6 `notify_user` is a flag-typed PM to the author | Exclude it from Report reasons |

### Controlled-account validation checklist

**Account restriction updated 2026-10-17.** The user authorized agent-created disposable accounts, replacing the earlier "user-supplied only" rule. Agent safety policy still forbids creating accounts or signing in with passwords on the deployed host. So:

- **Local, done by the agent:** disposable TL0/TL1/TL2, target author, staff and moderator accounts in an isolated test database at the deployed revision, using per-user API keys with the native scopes.
- **Deployed:** accounts must be created and signed in by a person, then used through the native per-user key flow. An already signed-in admin browser session is needed for read-only settings inspection.

Disposable accounts and approved content only, with a cleanup plan, never real people, and credentials kept out of source, docs and chat.

Record before/after values. Never test against real people.

1. Admin read: `flag_post_allowed_groups`, `allow_all_users_to_flag_illegal_content`, `allow_flagging_staff`, `max_flags_per_day`, `cooldown_hours_until_reflag`, `min_personal_message_post_length`, `ignore_allowed_groups`, watched words (block/require approval/censor), new-user link/upload limits, approval settings.
2. For each of TL0, TL1 and TL2: read `actions_summary` on an ordinary reply, the opening post and an ignored reply (via a fresh post fetch); read topic `details.can_flag_topic`.
3. Report as an eligible member:
   - Off-Topic on a reply: success → post payload.
   - Repeat → `acted`, no `can_act`.
   - Something Else with details → moderators PM plus reviewable.
   - Whole discussion with `flag_topic=true`.
   - Ineligible account → 403.
   - Rate limit → 429 with `Retry-After`.
   - Removed post → 404.
   Confirm each report lands in the web review queue and is handled.
4. Ignore as an eligible account:
   - Forever (Discourse's 1,000-year convention) → `can_ignore_user`/`ignored` on the user card.
   - `session/current.json` `ignored_users` on a second client.
   - New PM from the ignored user rejected; post notification suppressed.
   - Staff and self denied.
   - `normal` clears both Ignore and Mute.
   - TL0/TL1 denied under the current setting.
5. Record sanitized payload shapes, status codes and gaps in the API reference. Then decide whether native implementation can start.

### Results — 2026-10-17

| Step | Status | Evidence |
| --- | --- | --- |
| 1. Admin settings read | **Done (read only)** in the built-in browser after the user signed in themselves; Chrome extension attempt had failed. Nothing changed. TL0 can report only Illegal; TL0/TL1 can't Ignore; no watched words | [API reference](../../discourse-api-reference.md#controlled-account-backend-checks--2026-10-17) |
| 2–4. Report/Ignore/denied/persistence checks | **Passed locally at deployed revision `28529a6d`** with disposable accounts and native-scoped user API keys (18/18), plus upstream specs (118/118, 13/13) | [API reference](../../discourse-api-reference.md#controlled-account-backend-checks--2026-10-17), [spec](../../validation/2026-10-17-safety-backend/fomio_safety_contract_spec.rb) |
| 2–4 on `meta.fomio.app` | **Not run; waived by the user (not passed).** Would need person-created, signed-in disposable accounts | — |
| Moderator delivery on the deployed queue | **Not run; waived (not passed); release item** | Local reviewable creation and handling passed |
| Cleanup | Local transactions rolled back; isolated database dropped; nothing written to the deployed site | API reference |

**User decision — 2026-10-17: deployed account round trips waived.** The user judged the deployed-member checks unnecessary. Basis: the deployed revision `28529a6d` matches the locally tested revision; deployed settings were read directly; core flag and Ignore behavior is covered by Discourse's own specs (131 passing at that revision) plus the 18 Fomio contract checks. The deployed TL0/TL1/TL2 round trips are therefore **waived, not passed**. Residual items stay open as release items, to be observed during native live testing with a real member account:
- plugin effects (local runs used `LOAD_PLUGINS=0`);
- delivery and handling in the real review queue, plus moderator staffing;
- grants on issued user API keys;
- existing/group PM and push/email behavior.

New contract facts that native work must follow:
- **Ignore denials return 422** (`ignore_error`), not 403. Refetch the user card to show the truthful state.
- The **OP body is returned even when its author is ignored**. Hiding it is client work.
- The reporter **still sees `acted` after moderator handling**.
- A repeat flag is **403**. The reachable rate limit is the **daily flag cap, 429**.
- A `require_message` flag **is accepted without a message**.

Backend gate: settings read done; local contract checks passed; deployed round trips waived by the user (see decision above). Native implementation awaits the user's explicit go-ahead. Proposed setting changes (`logged_in_users` for Ignore; flag eligibility after the read) await approval and are not applied.

## Stage 3 status — 2026-10-17

The user authorized native implementation after the backend gate (settings read; local contract checks passed; deployed round trips waived). The native feature is implemented in the working tree and passes fixture-mode unit and UI tests on iPhone and iPad simulators: [validation](../../validation/2026-10-17-safety-native/README.md).

Design reconciliations applied:
- Send report sits in the sheet toolbar, per the R03/A02 wireframes.
- Ignored users has no per-row duration, because no API exposes expiry.
- Details are required client-side for `require_message` reasons.
- Reporting an ignored reply rechecks the fresh post.
- TL0 sees Illegal only, from the server's `can_act`.
- Contact comes only from the server's `contact_email`.

Open before release:
- First live native run with a real member account, covering plugin effects, real review-queue delivery and issued-key scopes.
- Native-speaker review of the draft Arabic safety strings (added 2026-10-18).
- Ignored-author suppression for Saved and link previews (feeds, search and notifications are done as of 2026-10-18).
- Manual VoiceOver pass and physical devices.
- Moderator staffing and response target.
- Settings decisions: `logged_in_users` for Ignore and flagging; watched words.

No TestFlight upload or App Review claim.
