# Member and restricted-category search verification

2026-10-20 (Asia/Amman). Follow-up to the [initial scoped-search packet](README.md). No app code, backend reference code, deployed accounts, permissions or settings were changed.

**Outcome:** 14 isolated local request examples passed, zero failures/pending/errors outside examples. Deployed administrator access and guest denial were checked against an existing restricted category. **Live ordinary-member acceptance remains blocked:** the user confirmed that only the administrator account is available. This is a resource limitation, not a passed permission check.

[Sanitized live observations](member-permissions-results.json) · [RSpec results](member-local-rspec-results.json) · [Replayable verification spec](member-permissions-spec.rb).

## Evidence matrix

| Case | Local full-page HTTP request tests | Deployed observation |
| --- | --- | --- |
| Guest selects restricted category context | 403, no posts | 403 `invalid_access`, no posts |
| Ordinary nonmember selects restricted context | 403, no posts | Blocked: no non-staff account |
| Ordinary authorized group member selects restricted category | 200, exact expected hit | Blocked: no non-staff account |
| Authorized read-only group member | Can search; cannot post in category | Not checked live |
| Public root contains restricted child | Guest/nonmember see public hit only; allowed member sees public + child hit | No restricted child in the inspected admin catalog; not fabricated on the deployed site |
| Numeric filter for inaccessible category, without explicit context | 200 empty, no private access | Guest 200 empty; this differs from the explicit-context 403 |
| Unscoped member search | Includes permitted restricted-category discussions; excludes inaccessible ones | Ordinary-member result unavailable |
| Per-user key with `read` scope | Authorized non-staff key gets the same permitted private-category hit | No new deployed key issued/extracted/tested |
| Default discussion search vs PM mode | Default excludes PM; `in:all` includes own permitted PM but excludes unrelated member PM | PM content was not read through the administrator session |
| Another member's PM selector | 403 | Not checked live |
| Unauthorized `topic:` target | Does not reveal target; tested request retains public root results | Not checked live for a nonmember |
| Administrator restricted-category search | Not substituted for ordinary-member tests | 3 regular-topic hits with exact identity, selected-category membership and no grouped error; same count with numeric filter alone |
| Positive public scoped continuation | Separate deployed check | Pages 1 and 2 each return 50 hits, `more_full_page_results=true`, all in the expected public child; 100 distinct exact hits |

Administrator browser evidence was read from JSON rendered in the browser DOM; HTTP status codes were not captured for those reads. Guest status codes were captured by a credential-free HTTP client. No cookie, key, username, private category name, private target ID or private post content is saved in the evidence. The existing target is represented as `restricted-root-A`; no IDs were guessed. The administrator catalog snapshot had 12 roots and one restricted root; it is not a complete ordinary-member catalog claim.

A restricted category contains normal community discussions (`archetype=regular` in the observed hits). It is **not** a Discourse private message. The native discussion-search policy must allow a viewer's authorized restricted-category discussions while preventing a query from switching into PM search.

## Feature packet

**Goal:** Establish that scoped search respects ordinary-member group membership, independent category reading/posting permissions and PM visibility before native implementation.

**Entry Point:** `GET /search.json` → `config/routes.rb` `search#show` → `app/controllers/search_controller.rb#show/#lookup_search_context`. This packet tests full-page `show`, rather than assuming header `/search/query` tests cover it.

**Client Trigger:** API-only verification. The native adapter still has no typed category scope; no app changes were made. Deployed staff verification reused an existing browser cookie session. Local tests cover both ordinary member sessions and a fabricated per-user `read` key.

**Server Path:** Context lookup invokes `guardian.ensure_can_see!`. `lib/guardian/category_guardian.rb#can_see_category?/#secure_category_ids` uses `User#secure_category_ids` (`app/models/user.rb`), which obtains group-permitted categories and has a setting-dependent administrator override. `lib/search.rb#posts_query` intersects query filters/context and then secure-category visibility. For PM modes, `Post.private_posts_for_user` (`app/models/post.rb`) uses the allowed-user/group queries in `app/models/topic.rb`. An unauthorized topic operator is not accepted as a visible topic context (`Search#process_advanced_search!`).

**Data Map:** Existing `categories.read_restricted`, `category_groups.category_id/group_id/permission_type`, `group_users.user_id/group_id`, `topics.category_id/archetype`, `posts.topic_id/post_number`, `topic_allowed_users` and `topic_allowed_groups` determine the boundary (`db/structure.sql`). `CategoryGroup.permission_types` defines full/create-post/read-only in `app/models/category_group.rb`. Category reading does not require create-post permission. Local fabricated rows exist only in a disposable database; deployed reads may record search logs as described in the initial packet.

**Permissions:** Source `Guardian#can_search?` allows an authenticated viewer independently of the anonymous-search site setting. Explicit inaccessible category context returns InvalidAccess; a numeric query filter instead yields no matching permitted posts. Administrator access is setting-dependent and cannot establish ordinary-member membership behavior. A scoped root does not authorize reading every child; results are filtered per permitted category. Native caches must remain viewer-specific, and account/permission denial must invalidate previously usable restricted results.

**Async Side Effects:** Same search logging/event boundary as the initial packet. Local test environment uses immediate jobs, test mail delivery and WebMock isolation from the existing test harness; no deployed write or membership change was performed. Disposable local PostgreSQL/Redis were stopped after verification.

**Realtime Side Effects:** No new direct search MessageBus publication was established. Plugin event handlers and deployed realtime behavior remain unknown.

**Serializer/JSON Contract:** `SearchPostSerializer` → joined `SearchTopicListItemSerializer`/`ListableTopicSerializer`: exact PostID, TopicID, PostNumber, category identity and topic archetype. Tests compare exact returned hit IDs, not just response success. Denied context is an error; numeric-filter empty is a valid empty envelope. UI must not infer category existence or permission solely from an empty result. Default topic search excludes PMs; HTTP `in:all` changes mode and returns permitted PMs. The earlier requirement to constrain mode-changing query grammar remains necessary; `exclude_private_messages` is not a public `show` parameter.

**Tests:** The saved verification spec has 14 passing request examples against fabricated ordinary members, a read-only group, restricted root/child, unrelated PMs and a per-user `read` key. Source reference was freshly checked at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. Existing corroborating assertions were inspected in `spec/lib/guardian_spec.rb` (“allows members of an authorized group”), `spec/lib/search_spec.rb` (“secures results correctly” and private-message examples), `spec/models/user_spec.rb#secure_category_ids` and `spec/lib/category_guardian_spec.rb#can_post_in_category?`. These upstream examples were not separately run in this follow-up.

The earlier Bundler blocker was resolved using Homebrew Ruby and `BUNDLE_FROZEN=true`: dependencies were satisfied without rewriting the reference lockfile. A `git archive` of the recorded revision was unpacked into `/private/tmp/fomio-member-permissions/backend`; installed JS dependency directories were cloned using copy-on-write. PostgreSQL 17 used a private Unix socket and dedicated `fomio_permissions_test` database; a separate Redis instance used loopback port 16389. Inherited Discourse/Rails/PG/Redis configuration was cleared and explicitly replaced for this runner. No configured production database was used.

Setup attempts and limits: sandboxed `initdb` initially failed on shared memory; the approved isolated retry succeeded. The first Rails setup used the default PostgreSQL socket and failed; explicit `PGHOST/PGPORT` fixed it. Seeding then needed installed JS dependencies, supplied by local clones. No packages were downloaded. Final RSpec result: 14 examples, zero failures/pending/errors outside examples. A simulator session-presence helper stalled; it was stopped without obtaining credentials. The deployed browser checks use cookie auth, not proof of a deployed native key flow.

**Safest Extension Plan:** Theme Component can present category state but cannot enforce native requests. Existing APIs already enforce the tested member/category permissions; no plugin/core change is justified for this issue. If unrestricted operators with an immutable scope later become required, evaluate a Plugin boundary after parsing before considering Core. This task authorizes no backend implementation.

**Verification Steps:**

```sh
git -C /Volumes/Develop/Projects/Dicourse rev-parse HEAD
rg -n 'def can_see_category|def secure_category_ids|def can_post_in_category' /Volumes/Develop/Projects/Dicourse/lib/guardian/category_guardian.rb
rg -n 'secure_categories|def secure_category_ids' /Volumes/Develop/Projects/Dicourse/app/models/user.rb
rg -n 'private_posts_for_user|secure_category_ids|topics.archetype' /Volumes/Develop/Projects/Dicourse/lib/search.rb /Volumes/Develop/Projects/Dicourse/app/models/post.rb
```

To replay the saved spec, copy it to `spec/requests/fomio_scoped_permissions_spec.rb` in an **isolated, configured test checkout**, then run `BUNDLE_FROZEN=true RAILS_ENV=test bundle exec rspec spec/requests/fomio_scoped_permissions_spec.rb --format json --out member-local-rspec-results.json`. Test DB/Redis must be disposable and explicitly isolated; never run a schema/seed task against deployed data. The session's temporary runner was `/private/tmp/fomio-member-permissions/run_isolated.py`; it is an environment-specific aid, not app source or a portable deployment configuration.

## Remaining acceptance gates

- A deployed ordinary member authorized for an existing restricted category, and a member denied that category; verify catalog, explicit context, numeric filter, unscoped results and exact-hit readback for each. Confirm staff flags before testing. Reuse a permitted matched term without publishing private text in evidence.
- Restricted child behavior on the deployed site, if such a category exists and is available to test. Do not change production membership/taxonomy to manufacture it under this task.
- Native query grammar, request/response/error/caching implementation and acceptance. This packet did not change app behavior.
- Positive pagination is now observed for one public scoped query. Exhaustive traversal, stable results during new posts, deployed revision/plugins/settings and authenticated continuation remain separate claims.

The ordinary-member source contract and isolated tests are established. The live ordinary-member gate stays open until a suitable account exists; administrator or guest results must not be relabeled as that evidence.
