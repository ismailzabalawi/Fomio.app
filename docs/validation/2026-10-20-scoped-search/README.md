# Scoped-search contract verification

2026-10-20 (Asia/Amman). Documentation/evidence only; no app or backend code changes. User explicitly requested the Discourse archeologist workflow before implementation.

Reference source: `/Volumes/Develop/Projects/Dicourse`, freshly checked at `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. Tracked source stayed clean; unrelated untracked `docs/sidebar-outlet-discovery.md` was unused. Configured deployed URL was read from `project.yml:40` and `Fomio/Info.plist:21`; deployed revision/settings/plugin inventory are **unknown**. No keys, cookies or authenticated sessions were used.

**Subsequent follow-up:** [member/restricted-category verification](member-permissions.md) adds 14 passing isolated request tests, deployed staff access/guest denial and positive public pagination. Its runtime results supersede the initial local-execution blocker below. Live ordinary-member verification remains blocked because only an administrator account is available. The original 22-request guest batch below is preserved as recorded.

**Operator/error follow-up:** [42 passing isolated examples and 5 guest reads](operators-and-errors.md) add the search-settings route, quoted/operator behavior, length-bypass and error rules, plus an unresolved swallowed-database-error signal. Earlier pending statements below are historical where superseded by these follow-ups.

**Backend fix follow-up:** [explicit database errors](../2026-10-20-search-database-error-fix/README.md) are now implemented and verified locally (359 passing examples, real PostgreSQL probes). This supersedes the later local failure-signal gap; deployment and native handling remain pending.

## Outcome

**22 public GETs recorded; 17 observations matched expectations.** These include intentionally reproduced unsafe assumptions, not 17 security/acceptance passes. [Sanitized machine-readable evidence](guest-results.json) retains request parameters, status, public IDs, field names and counts, without post bodies, names, raw errors, credentials or private records. One earlier catalog discovery GET was also made before the recorded batch; it is not included in the 22.

| Observation | Live guest result |
| --- | --- |
| `q=Fomio` globally | 9 hits across 7 category IDs |
| Same query, category context 45 | 8 hits, all in root 45 or its visible children |
| Same query, child context 12 | 1 hit, category 12 |
| Same query, child context 47 | Valid 200 with no hits; not a denied-category diagnosis |
| Nonexistent context ID 2147483647 | 403 `invalid_access` |
| `context=category` with missing ID | **200 global results**, identical to baseline; a malformed scoped request fails open to global search |
| `Fomio topic:5` with category context 45 | **1 hit in category 4**; the topic operator replaced category context |
| Add generated `category:45` to that conflicting query | 200, zero hits: category filter intersects the replacement topic context |
| `Fomio category:45` plus context 45 | Same 8 hits as normal category-context search |
| `category:4 category:45` | Zero hits; separate category filters intersect in the tested case |
| Search page 11 | 400 `invalid_parameters` |
| Search page 2 for the scoped sample | Valid empty page; does not test a positive continuation |
| Nonmatching term | 200 with empty `posts` and omitted `topics`; no grouped error |
| Query length boundary (`x`, `xy`, `xyz`) | 1/2 characters rejected, 3 accepted in these requests; not a universal locale/site-setting discovery |
| Catalog page 1/2 | 11 roots + 9 embedded children; page 2 empty |
| Root 4 and 45 child-list requests | IDs match embedded child IDs/counts in this guest catalog |
| Category feeds 45 and 12 | Results inside the expected scope; root feed includes child categories, child feed only category 12 |

The root feed and root search do **not** have equal result sets/counts. Search relevance, matching posts, definition-topic exclusions and other server rules differ from Latest. `TopicQuery#default_results` explicitly excludes child category-definition topics when configured, while retaining category scope. Do not assert that searching a root must return exactly its loaded feed rows.

## Feature packet: scoped public discussion search

**Goal:** Connect selected community scope to correct permitted search-hit destinations without silently broadening scope.

**Entry Point:** `GET /search.json` → `config/routes.rb` `search#show` → `app/controllers/search_controller.rb#show`; `lookup_search_context` accepts `context=category&context_id=ID` or nested `search_context[type/id]`. `/search/query.json` is a different header-search contract and is not substituted here.

**Client Trigger:** API-only native intent; current `Fomio/Data/DiscourseService.swift#search` has query/page but no typed scope. The mockup's substring filtering is not the production contract. Reveal/chooser/resize are local presentation actions.

**Server Path:** `SearchController#show` validates `q/page`, checks eligibility, resolves visible context and rate limits, invokes `Search.new/#execute`; `Search#initialize/#process_advanced_search!` parses operators **after** initial context assignment; `#posts_query` applies filters/context/visibility; `#aggregate_search/#aggregate_post_sql` choose matched posts; `Search::GroupedSearchResults` handles paging and blurbs.

**Data Map:** `db/structure.sql`: categories (`id`, `parent_category_id`, `read_restricted`, `topic_id`), topics (`id`, `category_id`, `archetype`, `visible`), posts (`id`, `topic_id`, `post_number`, `reply_to_post_number`), search-index tables, and `search_logs` (`term`, user/IP/session/result metadata). `Category.subcategory_ids` traverses descendants including the root; category search context in `Search#posts_query` adds only immediate children. The accepted two-level taxonomy aligns them; deeper deployment requires separate review.

**Permissions:** `Guardian#can_search?` permits authenticated users or anonymous search when enabled. `SearchController#lookup_search_context` calls `guardian.ensure_can_see!`; `EnsureMagic#ensure_can_see!` raises InvalidAccess when missing/inaccessible. `Search#posts_query` still applies secure-category and private-message visibility. `UserApiKeyScope::SCOPES[:read]` permits GETs for member reads; no administrator key is required. Missing top-level context ID bypasses context construction: validate both fields before sending. Rate limits use separate authenticated/anonymous-IP/global buckets (`SearchController#rate_limit_search`); values are site-specific.

**Async Side Effects:** The search read can synchronously write/update `search_logs` and Redis when `Search#log_query?` permits it. `Search#trigger_user_search_event` emits `DiscourseEvent(:user_search)`, whose installed handlers are not audited here. No direct search-time Sidekiq enqueue was identified in this call path; do not promise the endpoint is side-effect-free. The verification sent no post/bookmark/upload/settings mutations.

**Realtime Side Effects:** No direct MessageBus publication found in the inspected controller/search execution path. Plugin/event handler effects remain unknown; no native realtime subscription is established by this verification.

**Serializer/JSON Contract:** `GroupedSearchResultSerializer` includes posts, users, categories, groups and grouped fields; `SearchPostSerializer` embeds a topic relationship using `SearchTopicListItemSerializer`; `ApplicationSerializer` uses ID embedding with included objects, producing top-level `topics` and post `topic_id`. Each hit has PostID and `post_number`; topic has CategoryID. Empty results can omit `topics`; grouped continuation/error fields can be absent/null. HTTP 200 plus `grouped_search_result.error` is a search failure, not empty success (request spec for overloaded `show`). Current native `SearchDTO` discards PostID and grouped error; its mapping must be revised before implementation.

**Tests:** Read, not run: `spec/lib/search_spec.rb`, examples “can use category as a search context”, “allow searching for multiple categories”, “aggregates searches in a topic by returning the post with the lowest post number”, “returns multiple posts per topic when using in:all-posts”, and private-message exclusion-mode example. `spec/requests/search_controller_spec.rb`: malformed/page-limit errors, anonymous-search-disabled 403, rate limits, overloaded `show` returning HTTP 200 with grouped error, context type/ID/visibility tests on `query`. The latter do not substitute for category-context `show` HTTP tests; deployed guest probes cover only their listed cases.

Local execution was not achieved. `/usr/bin/bundle check` selected system Ruby 2.6 without Bundler 4.0.11; the explicit Homebrew Ruby/Bundler invocation then attempted a lockfile write and failed EPERM in the read-only reference. `git diff --exit-code -- Gemfile.lock` passed afterwards. No gems installed, lockfile rewritten, database tests launched, or backend configuration changed. Request specs include database/Redis operations and must run in a configured isolated test environment.

**Safest Extension Plan:** Theme Component can style the web chooser/search but cannot enforce the SwiftUI client's request semantics. For the native app, reuse existing APIs with a typed category scope, a generated numeric category constraint and strict query/response checks as specified below; no backend extension is currently justified for the constrained client. If the product later requires unrestricted Discourse operators with an immutable server-side category boundary, assess a Plugin endpoint/service wrapper that applies the final category restriction after operator parsing and excludes PMs; only consider Core if a plugin cannot meet that requirement. No such backend work is authorized here.

**Verification Steps:**

```sh
git -C /Volumes/Develop/Projects/Dicourse rev-parse HEAD
rg -n 'def show|lookup_search_context|PAGE_LIMIT|rate_limit_search' /Volumes/Develop/Projects/Dicourse/app/controllers/search_controller.rb
rg -n 'process_advanced_search|topic:|personal_messages:|def apply_filters|search_context.is_a|aggregate_post_sql' /Volumes/Develop/Projects/Dicourse/lib/search.rb
rg -n 'can use category as a search context|returns multiple posts per topic|aggregates searches in a topic' /Volumes/Develop/Projects/Dicourse/spec/lib/search_spec.rb
```

In a prepared **isolated backend test environment**, execute focused `bundle exec rspec spec/requests/search_controller_spec.rb spec/lib/search_spec.rb`; this was not run here. Reproduce the guest requests with the configured site URL and parameters in `guest-results.json`, observing rate limits and stopping on 429. Do not send a member key in a URL or save it in an evidence file.

## Resolved client contract and remaining gates

1. **Typed scope is mandatory.** All emits no category context or category constraint. Category requires a positive ID from the viewer's catalog; never fall back to All when malformed or unresolved. Validate schema before transport.
2. **Context alone is insufficient.** The planned request sends both category context and a generated standalone numeric `category:ID` constraint as the final token. This guard uses `Search#apply_filters` intersection and `Category.subcategory_ids`; the specific conflicting-topic and conflicting-category probes above passed. Do not treat this small live sample as a proof over all arbitrary search syntax/plugins.
3. **Constrain the native query grammar before shipping.** The first native scoped-search contract does not expose unrestricted advanced operators. Reject scope/mode-changing operators (`topic:`, PM selectors, `in:all`/PM modes and user-supplied category scope operators) with a visible explanation while preserving the user text. Use parser-aware validation, including quoted forms; quoting alone is not a general escape because `process_advanced_search!` removes quote characters for advanced-filter matching. Do not silently strip tokens or assemble parameters from raw URLs. Allowed ordinary/phrase input and any approved narrowing operators need request-builder tests. The same public-discussion policy applies to All: a member query must not silently switch to private messages. `exclude_private_messages` exists as an internal Search option but is **not forwarded by `show`**; do not invent a public query parameter for it.
4. **Validate responses before display.** Every post must resolve to a returned topic, contain a positive exact post number/ID, remain inside the permitted selected scope and public-discussion policy, and belong to the active account/scope/query generation. Unexpected out-of-scope data is an explicit contract error; do not silently drop it then claim “no matches” or trust its pagination. This is a defense against shape/contract drift, not a replacement for server authorization.
5. **Correct result identity.** Default topic search aggregates one chosen matching post per topic; that post need not be OP. `in:all-posts`, topic contexts and some ordering modes can return multiple posts. Preserve both PostID and `(TopicID, PostNumber)` and deduplicate exact hits, not every TopicID. Do not claim multiple hits per topic are the default.
6. **Correct paging/errors.** Search starts at 1, max 10 in inspected source and tested rejection. Stop when continuation is not true or at the limit; reaching a cap is not exhaustive search. Empty response can omit topic metadata; HTTP and grouped errors are first-class. No positive multi-page continuation was available in these samples.
7. **Current catalog evidence is guest-specific.** Today's observed catalog is 20 visible categories, not the historical 26; do not infer deleted/private category identities or current admin taxonomy. Successful child completion/page-2 exhaustion for this guest state does not close lazy-category configurations or ordinary-member permission matrices.

Still pending: native request-builder/DTO/cache changes (not made), adversarial grammar tests, authenticated ordinary-member/private-category denial and PM-mode tests, positive search continuation, unknown deployed revision/plugins/settings, local backend spec execution, and native UI/keyboard/accessibility validation. These remain explicit gates in the map; this pass resolves the wire semantics and documents live guest behavior rather than relabeling every gap “done.”
