# Search-error deployment verification

2026-10-20, verified 17:40 UTC (20:40 Asia/Amman). **Deployed and activated on `https://meta.fomio.app`. No iOS app code changed.** User authorized the rollout and access through the existing DigitalOcean Web Console in Arc.

## Release identity and rollout

Droplet `meta.fomio`, ID 420498845; existing `app` container. Its clean source was `821e9e2f9f94483a3be8d1e077cde0fd94970479`, confirmed through the container's owner account, file hashes and public generator metadata. This is newer than local reference HEAD `d4296c5…`. The patch was reapplied to an isolated archive of the actual deployed revision, preserving its newer search-weight filtering and translations. Local backend HEAD and the user's unrelated changes were preserved.

Only `lib/search.rb` and `config/locales/server.en.yml` were applied to the running container. [Runtime patch](runtime.patch), [four-file tested release patch](release.patch), [manifest](manifest.json), [guarded rollout script](deploy.py). No core/plugin upgrade, migration, credential, permission or site-setting change was made. Ordinary search logging may occur from read probes. The existing image ID remains unchanged; **the revision alone is insufficient to identify this release: use revision plus runtime patch/file hashes**.

A separate `after_code` exec was appended to `/var/discourse/containers/app.yml`, preserving the rest of the parsed configuration and existing plugin hooks. It embeds the patch, uses Git as the `discourse` owner, checks before applying, and accepts an already-applied patch. The idempotent path passed inside the container. The forward path passed during deployment. A complete launcher rebuild was not run. Incompatible future source must fail the hook rather than silently skip the fix. Web/admin updater behavior is unverified; it may reject or replace local core changes and does not establish execution of launcher hooks. Carry the fix into the maintained release source and repeat verification before future upgrades.

Root-only backups of the two original files, launcher config, patch, image receipt and probe log are on the Droplet at `/root/fomio-search-error-backup-20261020` (directory mode 0700). The secret-bearing launcher config was never copied into this repository or printed. The Unicorn supervisor was restarted; service status subsequently showed PID 354718 running. PostgreSQL, Redis and nginx were not restarted.

## Verification

- **305 examples passed** on the deployed-base candidate: complete Search library and search controller suites, zero failures/pending/outside errors. [RSpec results](release-tests.json). This is a fresh aligned run, in addition to the earlier 359-example local matrix; do not sum them as unique coverage.
- Required targeted `bin/lint --fix` passed. [Lint log](release-lint.log). Initial attempts needed a disposable Git directory and writable RuboCop cache; no source change resulted. Runtime file hashes still matched the deployed files after lint.
- **Both deployed endpoint failure paths passed in an isolated production Rails process**, loading the actual container code and plugins. [Probe source](deployed-probe.rb), [sanitized results](probe-results.json). A process-local replacement of `Search#posts_query` raised a synthetic `ActiveRecord::StatementInvalid`; it was restored in `ensure`. Actual Rails routes/controllers/serializers returned HTTP 200 with `grouped_search_result.error = "Search could not be completed. Please try again."`, empty collections, no topics/continuation, and no raw error detail. No production database fault, public fault switch, limiter bypass or public worker monkey patch was used. This is deployed-process contract verification, **not a fault forced through public HTTPS**.
- Public HTTPS after activation: populated `/search.json` → 200/9 posts; populated `/search/query.json` → 200/5 posts; unique zero-match term → 200/0 posts/no grouped error on both endpoints. Numeric category/context request → 200/8 posts/no grouped error. Short `xy` → 400 `invalid_parameters`. Homepage → 200 with the same base revision. [Before](preflight-results.json), [after](post-deploy-results.json).
- Visible console receipt records service status, two-file diff and both isolated error responses.

The caught grouped database-query error is now distinguishable from genuine zero matches in this deployed release. This does not cover every exception or grant ordinary-member permission acceptance. Only an admin account is available; live non-staff private-category/member checks remain open. Native `SearchDTO` still ignores grouped errors; client grammar, settings/cache integration and five-layout acceptance remain separate gates.

## Rollback runbook

On this same unchanged release, first compare the current two runtime hashes and launcher config against the host deployment receipt. If later changes exist, reconcile rather than overwrite them. Restore the two original files from the root-only backup into `/var/www/discourse/` in `app`, preserve `discourse` ownership, restore the backed-up `/var/discourse/containers/app.yml` to remove the hook, then restart Unicorn with `docker exec app sv -w 60 restart unicorn`. Repeat populated/empty search checks. Reversing `runtime.patch` after `git apply --reverse --check` is an alternative when hashes still match. Rollback was prepared, not executed; it would restore the old swallowed-error behavior. No database rollback is needed.

## Archeologist feature packet

**Goal:** deploy the authorized explicit search-error fix and align the IA/API map before native changes. **Entry point:** both JSON search routes. **Client trigger:** normal full/debounced search; synthetic failure only inside the separate verification process. **Server path:** routes → `SearchController#show/query` → `Search#execute/find_grouped_results` → existing grouped serializer. **Data map:** read-only search indexes and existing envelope; no schema change. **Permissions:** unchanged Guardian/per-user rules; no administrator key embedded or extracted. **Async/realtime:** no new job/event/channel; failed results return before successful-search preload/event processing. **Serializer:** existing `grouped_search_result.error`; no new endpoint/schema. **Tests:** aligned 305 examples, lint, two deployed-process failure requests, seven public reads. **Safest extension:** narrow authorized core correction; persisted launcher hook plus runtime checksum receipt, with future upgrade integration explicitly unresolved. **Confidence:** observed for this release and listed guest/process cases, not all roles or all failures.

Reproduce using at least these inspected commands (use the release-aligned candidate for tests):

```sh
docker exec -u discourse app git -C /var/www/discourse rev-parse HEAD
docker exec app sha256sum /var/www/discourse/lib/search.rb /var/www/discourse/config/locales/server.en.yml
bin/rspec spec/lib/search_spec.rb spec/requests/search_controller_spec.rb
bin/lint --fix lib/search.rb config/locales/server.en.yml spec/lib/search_spec.rb spec/requests/search_controller_spec.rb
docker exec app sv status unicorn
```
