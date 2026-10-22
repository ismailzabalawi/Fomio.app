# Search operators and error handling verification

2026-10-20 (Asia/Amman). Documentation and verification harnesses only. No app code, backend reference code, deployed settings, permissions or content were changed. Uses the same source-tracing workflow as the [initial packet](README.md) and [member follow-up](member-permissions.md).

Reference HEAD freshly checked: `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`. Deployed revision/plugins remain unknown. **Final local result: 42 passing request examples** (37 operators/errors, 3 settings, 2 fault-observability checks); **5 spaced guest GETs** recorded. These include reproduced hazardous behavior, not 42 acceptance passes for a hardened client. No deployed overload/rate-limit fault was induced and no member credentials were used in this pass.

Evidence: [operator/error results](operators-errors-rspec-results.json), [settings results](search-settings-rspec-results.json), [fault results](search-faults-rspec-results.json), [guest reads](operators-errors-guest-results.json). Replay specs: [operators/errors](operators-errors-spec.rb), [settings](search-settings-spec.rb), [faults](search-faults-spec.rb).

**Authorized backend follow-up:** the [database-search fix packet](../2026-10-20-search-database-error-fix/README.md) records the subsequent local correction and 359 passing examples. The swallowed-error result below is preserved as pre-fix evidence; local behavior is superseded, deployment remains pending.

## Resolved operator semantics

| Input/parameter | Verified behavior | Planned client rule |
| --- | --- | --- |
| `topic:ID`, uppercase variant | Replaces category context when target is visible; numeric category constraint intersects it | Reject topic selectors in the first native discussion-search grammar |
| `category:`, `categories:`, uppercase, `=ID`, comma list | Filters match exact/descendant/union forms; separate generated constraint intersects them | Generate one trusted numeric category token; reject user-supplied category constraints |
| Double/single-quoted category token | Still interpreted as a filter, not literal text | Quoting is not a general escape; validation must consider operator-specific parsing |
| Balanced ordinary phrase | Matches expected scoped phrase hits | Support terms/phrases without rewriting the original input; native validation tests pending |
| Unmatched quote combined with topic override | Numeric guard held for the tested sample | Require balanced phrase delimiters; this sample is not proof for all malformed grammar |
| `in:all-posts` | Returns separate matching posts within a topic | Exclude unexposed modes initially; retain exact PostID and TopicID/PostNumber regardless |
| `in:all` with `type_filter=topic&exclude_private_messages=true` | Still includes the ordinary member's permitted PM | These HTTP parameters are not an exclusion guarantee on `show`; reject mode-changing syntax |
| Unknown category filter | HTTP 200, empty results, no grouped error | Server emptiness is not validation of supported client syntax or category access |
| `skip_context=true` | Removes top-level context; generated numeric guard still held in the tested request | Never copy arbitrary URL parameters into a native request |
| Nested `search_context` alongside top-level context | Nested context wins; invalid type/missing nested ID returns 400 | Native builder emits only one structured context form and requires its ID |
| `x` or empty input + generated category token | Becomes HTTP 200 category results locally; guest `xy category:45` returned 11 hits | Validate original meaningful user text **before** adding the generated token; empty text restores feed |

Source also recognizes sorting and narrowing shorthand (`l`, `r`, `t`, `order:`, `#`, `@` and registered filters). Their full grammar was not exhaustively tested here. The proposed first native contract exposes ordinary terms and balanced phrases, with advanced operators/shorthand outside that initial grammar. Validation must detect reserved syntax including case/quote variants, preserve the user's input, and explain unsupported syntax. Do not silently strip tokens, claim every quoted operator behaves identically, or treat a small denylist as proof against all plugins. URLs/colon text and future narrowing operators need explicit grammar decisions/tests before being advertised as literal searches. No native parser or request builder was implemented in this task.

Only the builder supplies `q`, canonical integer `page`, and (for category scope) `context=category` plus `context_id`. All supplies no category constraint/context. Do not forward `skip_context`, nested context from incoming URLs, `type_filter`, an invented PM-exclusion option, or unknown request fields.

## Minimum length now has a verified API connection

`GET /site/settings.json` returns client settings, including `min_search_term_length` and `default_locale`. The isolated request test changed the minimum to 5 and received 5; guest deployed JSON returned minimum **3**, locale **en**. This does not make 3 universal. `allow_anonymous_search` is not client-exposed by this source, so infer availability from search responses rather than an absent flag.

Settings are subject to normal site authentication: isolated guest read on a login-required site returned 403, while an ordinary member succeeded. `/site/basic-info.json` is a separate, always-readable bootstrap and does not supply this minimum. Cache validated settings by site/viewer context, revalidate as needed, and represent unavailable/invalid settings explicitly. Native settings fetch/DTO, semantic term-length validation and locale behavior remain implementation gates. A generated category token must never turn empty/short user input into a browse request masquerading as search.

## Error contract and recovery map

| Observable outcome | Verified source/local behavior | Required native handling (not implemented here) |
| --- | --- | --- |
| 400 `invalid_parameters` | Short unguarded q, q hash, null byte, malformed page, page 11, invalid/missing nested context ID | Preserve input/scope; validate owned parameters and show actionable validation. No fallback to global search or automatic retry loop |
| Page `0`/`-1` | Normalized to page 1, not rejected | Builder still emits only canonical pages 1–10 |
| 403 `not_logged_in` | Guest search disabled | Offer sign-in and retain search intent |
| 403 `invalid_access` | Denied context, expired or revoked per-user key | Cannot classify every 403 as category denial or every 403 as expired auth. For a member request, validate the session through the existing authenticated session contract before deciding; do not silently downgrade to guest or discard credentials on every denied search |
| 429 search limiter | `{failed:"FAILED", message:…}`; tested response has no `Retry-After` | Retain query/results; use valid Retry-After when supplied, otherwise a bounded client backoff/manual retry. Never require that header or flood the endpoint |
| HTTP 200 + nonempty `grouped_search_result.error` | Full-page overload result, empty posts | Treat as retryable search failure **before** mapping hits, publishing cache or declaring no matches. Header `/search/query` overload uses a different contract |
| HTTP 200 + valid empty envelope, no grouped error | Empty posts, topics can be omitted | Observable no-match result; preserve the observability limitation below |
| HTTP 200 invalid JSON/shape, missing joined topic, invalid identity/scope/archetype | Client contract failures; not fault-injected on deployed site | Decode/validate explicitly. Never compactMap broken hits into an apparent empty success. Native tests remain pending |
| Offline, cancellation, stale response, 5xx | Proposed client lifecycle rules; not new deployed fault tests | Keep failures distinct; discard stale generations, cancel quietly, retain only same-key permitted data, offer bounded retry. Native cancellation/URLSession behavior remains unverified |
| Page 10 still advertises more | Source cap is 10; no exhaustive traversal claim | Stop at cap and offer query refinement; never request page 11 or label capped results exhaustive |

**A server error-observability gap remains open.** `Search#find_grouped_results` rescues `ActiveRecord::StatementInvalid` without setting a grouped error. A local-only injected exception in `topic_search` reproduced HTTP 200, `posts=[]`, and no grouped error for a query that had just returned a known hit. The public response cannot distinguish this failure from a legitimate empty search. This does not establish that the deployed site has experienced that fault. Client validation can catch signalled errors and malformed envelopes; it cannot recover a missing signal from an otherwise valid empty response. Resolving that server behavior requires a separately authorized backend task and deployment verification. Do not invent a client error heuristic or automatically repeat empty searches.

The JSON-suffixed route remained a valid JSON search object for a crawler user-agent in the local check; HTML crawler behavior on `/search` must not be assumed to apply to `/search.json`.

## Feature packet

**Goal:** Establish search operator, settings and error contracts before native query composition or UI changes.

**Entry Point:** `config/routes.rb` `GET /search` → `app/controllers/search_controller.rb#show`, and `site` namespace settings route → `app/controllers/site_controller.rb#settings` (JSON-suffixed requests tested).

**Client Trigger:** API-only isolated verification and 5 public GETs. Current native `DiscourseService.search` sends unscoped q/page/type_filter, ignores grouped error and drops invalid joined hits; `SearchView` accepts two characters. None was changed.

**Server Path:** `SearchController#show/#lookup_search_context/#rate_limit_search/#site_overloaded?`; `Search#initialize/#process_advanced_search!/#min_length_bypass?/#posts_query/#find_grouped_results/#execute`; `SiteController#settings` → `SiteSetting.client_settings_json` / `lib/site_setting_extension.rb#client_settings_hash_uncached`. `config/site_settings.yml` marks the minimum client-visible; anonymous-search availability is not client-visible.

**Data Map:** Existing search indexes/posts/topics/categories and permission relations from earlier packets remain authoritative. `site_settings` supplies persisted overrides, combined with defaults/locale defaults. Source `SearchLog.log` can write `search_logs` and Redis; no posts, memberships or settings were written on the deployed site. All fabricated rows and settings changes were isolated local test data.

**Permissions:** Guardian category/PM checks remain active after operator parsing. Expired/revoked keys are excluded by `UserApiKey.active`; `lib/auth/default_current_user_provider.rb` raises InvalidAccess when lookup fails, and `ApplicationController` serializes 403. This differs from assuming authentication failure must be 401. Search and settings login requirements were tested locally; deployed non-staff acceptance remains blocked by account availability.

**Async Side Effects:** Search logging and `:user_search` event as recorded earlier; installed plugin handlers remain unknown. Local harness used test mail and existing job/test isolation. No deployed load fault, rate-limit flood or mutation was induced. Disposable test services were stopped afterwards.

**Realtime Side Effects:** No new direct search MessageBus behavior established. Native search has no new realtime contract. Client settings refresh/caching behavior is proposed, not implemented.

**Serializer/JSON Contract:** `GroupedSearchResultSerializer` wraps error/continuation and post relationships; `SearchPostSerializer`/`SearchTopicListItemSerializer` retain exact identity/category/archetype. `ApplicationController` maps invalid parameters, not-logged-in and invalid access; controller-owned 429 differs from the general limiter rescue with Retry-After. `SiteSetting.client_settings_json` returns a settings object, not a category/search envelope.

**Tests:** Final 37 operator/error + 3 settings + 2 fault examples passed in the disposable archive of the recorded HEAD, using the previously prepared private-socket PostgreSQL database and separate Redis instance. Source tests consulted: `spec/requests/search_controller_spec.rb` full-page validation/overload/limiter examples and `spec/requests/site_controller_spec.rb`; final verification specs/results are linked above. The prior 14 permission examples were not rerun because their implementation/fixtures were unchanged.

Exploratory expectation corrections are retained: [settings initial result](search-settings-initial-results.json) wrongly expected the anonymous-search flag to be exposed; [fault initial result](search-faults-initial-results.json) wrongly expected a crawler HTML content type on the JSON route; [second fault result](search-faults-second-results.json) then wrongly expected a non-object body. Actual JSON-route behavior is a standard search object. Only verification expectations changed; no backend behavior was patched. The database-error masking example passed throughout. Final result counts refer to the corrected specs.

**Safest Extension Plan:** Theme can present errors but cannot restore a missing server failure signal. Reuse existing endpoints for the constrained native grammar and settings/error handling. For the swallowed database exception, assess a Plugin/service integration that tracks execution failure and exposes an explicit failed outcome; consider Core only if a supported plugin approach cannot provide the contract. No backend implementation or deployment is authorized by this verification task.

**Verification Steps:**

```sh
git -C /Volumes/Develop/Projects/Dicourse rev-parse HEAD
rg -n 'def show|lookup_search_context|rate_limit_search|site_overloaded' /Volumes/Develop/Projects/Dicourse/app/controllers/search_controller.rb
rg -n 'MIN_LENGTH_BYPASS|process_advanced_search|rescue ActiveRecord::StatementInvalid' /Volumes/Develop/Projects/Dicourse/lib/search.rb
rg -n 'def settings|client_settings_json' /Volumes/Develop/Projects/Dicourse/app/controllers/site_controller.rb /Volumes/Develop/Projects/Dicourse/lib/site_setting_extension.rb
```

Replay the saved specs as `spec/requests/fomio_search_{operators_errors,settings,faults}_spec.rb` in a prepared isolated test checkout and run `BUNDLE_FROZEN=true RAILS_ENV=test bundle exec rspec` with those three paths. Never point test setup at deployed databases/Redis. Live guest request parameters/statuses are retained in the linked evidence; no credentials belong in URLs or evidence files.

Remaining: native grammar/DTO/error/session/cache implementation and tests; separately authorized correction of the server's swallowed-error signal; live ordinary-member permissions; deployed revision/plugins and broader locale/settings compatibility. The operator/error semantics above are now verified at the recorded source and selected guest cases; they are not a claim that the native client is hardened.
