# Explicit database-search errors

2026-10-20 (Asia/Amman). User authorized a Discourse backend fix before any native app work. **Local backend fix implemented and verified. Subsequently deployed: see the [deployment packet](../2026-10-20-search-error-deployment/README.md). iOS app code is unchanged.**

Backend base revision: `d4296c5ecf2bef4f11e42d8f3fd2282c8752f4e2`, plus the uncommitted [four-file patch](backend.patch). [Manifest](manifest.json) records patch/file SHA-256 hashes; HEAD alone does not identify the patched behavior. The pre-existing untracked `docs/sidebar-outlet-discovery.md` was preserved.

## Result

A caught `ActiveRecord::StatementInvalid` in grouped search now produces a fresh result with a localized error, rather than an apparently successful empty or partial result. Both `GET /search.json` and `GET /search/query.json` preserve the existing JSON envelope and HTTP 200 contract:

```json
{
  "posts": [],
  "grouped_search_result": {
    "error": "Search could not be completed. Please try again.",
    "more_full_page_results": null
  }
}
```

This is an abbreviated failure envelope, not a new standalone schema. Other ordinary envelope keys remain. No partial posts/users/categories/tags/groups are retained; topic metadata is absent. Raw database details are logged server-side through the standard exception logger and are excluded from the client response. Successful zero-match searches still return empty posts with no grouped error.

The iOS client still needs its planned grouped-error decoder/handling; no native change was bundled with this fix. An HTTP 200 alone is not search success.

## Verification

- **359 final request/library examples passed**, zero failures/pending/errors outside examples: complete `spec/lib/search_spec.rb` and `spec/requests/search_controller_spec.rb`, plus the earlier 14 permission, 37 operator/error and 3 settings examples. [Final results](test-results.json). The historical fault-observability spec asserting the old swallowed-error behavior was not included; it remains dated pre-fix evidence.
- Initial search-only run: **305 passed** before the final formatted verification. [Initial results](initial-search-suite-results.json).
- **Real PostgreSQL fault checked on both JSON endpoints.** In a separate disposable Rails process, an unavailable text-search configuration caused an actual `PG::UndefinedObject` query error. Both endpoints returned the explicit localized grouped error, empty posts, absent topics and no leaked configuration name. Restoring the process-local configuration returned normal empty/no-error JSON. [Sanitized observations](postgres-fault-results.json), [probe](postgres-fault-probe.rb).
- Required `bin/lint --fix` passed: RuboCop and Syntax Tree on the changed Ruby files; `git diff --check` passed. Initial lint caught a duplicated `#execute` spec group; its example was moved into the existing group and checks reran successfully.
- The first real-PG probe delivered both explicit errors, then hit the local limiter during its final recovery check. The isolated probe process was rerun with its limiter disabled and all three observations passed. No deployed limiter was disabled or exercised by this task.

Tests ran against exact copies of the formatted backend files in `/private/tmp/fomio-member-permissions/backend`, using the previously prepared private-socket PostgreSQL database and separate loopback Redis. No deployed HTTP faults, production data, real credentials or deployment settings were used. Disposable services were stopped after verification. This is not production rollout evidence.

## Feature packet

**Goal:** Make a failed grouped database search explicitly distinguishable from a valid empty result, without changing native app code.

**Entry Point:** Existing search routes in `config/routes.rb`: `GET /search.json` → `SearchController#show`; `GET /search/query.json` → `#query` (`app/controllers/search_controller.rb`). Both already use `GroupedSearchResultSerializer`.

**Client Trigger:** Existing API-only or web search request. No new request parameter, authentication scope, endpoint or iOS behavior.

**Server Path:** `lib/search.rb#find_grouped_results` retains the existing `ActiveRecord::StatementInvalid` rescue but logs the exception, replaces partial results with a new `GroupedSearchResults` retaining type/term/context, and sets `I18n.t("search.query_error")`. `Search#execute` returns this failed result before preload hooks and successful-search events. This fixes the previously inspected rescue boundary; it does not claim every exception throughout initialization, logging or serialization is converted into a grouped error.

**Data Map:** No schema, permissions or content changes. Existing search-index/Post/Topic/Category queries remain authoritative. Normal search logging may precede query execution; the failure does not publish content. No migration or new database relation.

**Permissions:** Existing Guardian/category/PM and user-key checks are unchanged. The previous permission/operator/settings matrices pass against the patch. Live ordinary-member acceptance remains blocked because only an administrator account is available.

**Async Side Effects:** Uses the standard server exception logger. Failed grouped queries return before preload hooks and the success-path `:user_search` event; no new job or retry is introduced. Search logging before the failed query remains possible.

**Realtime Side Effects:** No new MessageBus publication or realtime subscription.

**Serializer/JSON Contract:** `Search::GroupedSearchResults` remains the source object for `GroupedSearchResultSerializer`. Existing `grouped_search_result.error` carries the translated safe message; the new translation lives at `config/locales/server.en.yml` → `search.query_error`. Continuation is not advertised for a failed result. Consumers must inspect the grouped error before mapping hits, updating caches or showing no matches. Normal 400/403/429/overload behavior remains covered by existing tests.

**Tests:** Three new regression examples: request outcomes on both endpoints and `Search#execute` discarding a partial user facet before a later query failure. The model regression first proves the user facet is normally returned, then injects a query-boundary failure and asserts empty collections plus an explicit error. Full source suites and previous matrices pass. The separate probe exercises a real PostgreSQL error without fabricating a production fault.

**Safest Extension Plan:** A Theme cannot restore the erased exception signal. The inspected supported search extensions are filters/orders, preload hooks and the later user-search event; none exposes the exception caught at this rescue boundary. A Plugin using those hooks cannot distinguish valid empty results from the swallowed failure. Replacing/prepending private query methods would duplicate/intercept core execution rather than use a supported error hook. The user explicitly authorized fixing Discourse; the small shared core rescue correction removes the defect for all existing callers without adding a plugin dependency or endpoint. No frontend/core API redesign was needed.

**Verification Steps:**

```sh
git -C /Volumes/Develop/Projects/Dicourse diff --check
rg -n 'query_error|return @results if @results.error|rescue ActiveRecord::StatementInvalid' /Volumes/Develop/Projects/Dicourse/lib/search.rb /Volumes/Develop/Projects/Dicourse/config/locales/server.en.yml
rg -n 'database search failures|discards partial results' /Volumes/Develop/Projects/Dicourse/spec/requests/search_controller_spec.rb /Volumes/Develop/Projects/Dicourse/spec/lib/search_spec.rb
```

In a configured isolated backend test environment, run `bin/rspec spec/lib/search_spec.rb spec/requests/search_controller_spec.rb`. The session also included the three previous request matrices from the temporary copy. Run `bin/lint --fix lib/search.rb config/locales/server.en.yml spec/lib/search_spec.rb spec/requests/search_controller_spec.rb` for the changed files. The supplied real-PG probe uses an environment-specific output path and must only run against disposable services.

## Remaining gates

Deploy/review the backend patch through the normal release process, then verify the deployed revision and explicit error signal in an authorized non-production fault workflow. Do not induce a production database failure to test this. No deploy, commit or push occurred here. Native grouped-error handling, input grammar/settings/cache integration, live ordinary-member checks and layout acceptance remain separate work.

Later deployment follow-up: the [release-aligned rollout](../2026-10-20-search-error-deployment/README.md) supersedes the deployment-pending state above. Earlier local results remain historical evidence.
