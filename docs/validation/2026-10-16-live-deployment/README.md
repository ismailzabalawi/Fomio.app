# Live deployment of discourse-fomio-app-locales: preparation, deployed-revision verification, blockers

Date 2026-10-16 (Amman; UTC 2026-10-15 22:30–23:00). App branch `claude/fomio-localization-impl-48ecab` (app source unchanged since `2dda70b`). Backend branch `fomio/app-locale-catalog`. `main` (`b62aef5`, build 0.8.0 (5)) untouched; nothing merged.

**Result (2026-10-16 ~11:30 UTC): v0.1.0 is deployed on meta.fomio.app (Discourse `28529a6d63f99d8dea00017e69981ab42d4700fc`) and verified live, anonymously and signed in. E2 passes, with one finding: conditional 304 doesn't work for compressed responses (weak ETag); the fix is v0.1.1, not yet released. E3 (live non-English) stays open: no non-English language is approved.** See [Deployment and live verification](#deployment-and-live-verification-2026-10-16). Sections after it record the preparation, in order.

## Deployment and live verification (2026-10-16)

### Deployment timeline (operator: the user, in the DigitalOcean droplet console; the agent never typed on the host)

| UTC | Event |
| --- | --- |
| ~09:05 | First `./launcher rebuild app` with the plugin clone added. The launcher pulled a newer base image, which ran a **PostgreSQL major upgrade from 15**. It completed (old data kept at `/shared/postgres_data_old`) and then stopped by design, asking for another rebuild. **The site was down** (443/80 refused at 09:11). |
| ~09:20–09:35 | Second rebuild: site back (`/srv/status` ok 09:36) on Discourse `f3758bd5a69`; plugin routes still 404. The rebuild output shown in the console printed the container's environment, including the SMTP credential. An agent screenshot captured it; it is not reproduced anywhere, and rotating it was advised. |
| later | The user fixed duplicate hooks in `containers/app.yml`. `docker_manager` and `fomio_plgin` were kept and `discourse-fomio-app-locales` `v0.1.0` added; then another rebuild. The user decided to keep Discourse **unpinned** for normal upgrades (no core version pin). Codex saw an initial 503 that cleared. |
| 10:54 | Live: generator `28529a6d63f99d8dea00017e69981ab42d4700fc` (1 commit after `f3758bd5a69`, 1,746 after the pre-deployment 7b4f0970). |

The Discourse upgrade (7b4f0970 → 28529a6d) and the PostgreSQL major upgrade were not planned parts of this change. They came from the launcher's default behavior; the user has since chosen to stay unpinned.

### Live HTTP (no fixture)

- **Anonymous** ([verify-postdeploy-anonymous.txt](verify-postdeploy-anonymous.txt), 10:54 UTC): all checks pass. `/srv/status` ok. Index 200 (`en` only, complete, `default_locale` en). `en` 200 with ETag `"fbb8458fccf9d8f0"`, 481 messages, `Cache-Control: max-age=300, public`. Conditional request 304 (uncompressed). No `X-Discourse-Username`. `xx`, schema 2, `AR` → 404; `ar` → 404 (not allowlisted). Bodies: [index](live-index-28529a6d.json), [en](live-en-fbb8458fccf9d8f0.json.gz).
- **Live English = app's bundled English**: same 481 keys, 0 value differences. Live: schema 1, ltr, plural categories `one, other`.
- **Signed in** ([live-member-and-etag-2026-10-16.txt](live-member-and-etag-2026-10-16.txt)): the user signed in to meta.fomio.app in the in-app browser. `/session/current.json` 200 showed a moderator, not an admin, trust level 1; the username isn't recorded. Same-origin `fetch` with that session cookie, no API key:
  - index and `en` 200, public 5-minute caching, same revision and content as anonymous;
  - no `X-Discourse-Username` on 200 or on the conditional request, and the username appears in no body;
  - `ar`, `xx`, schema 2, `AR` → 404.
- **Finding, weak ETag**: compressed responses (`content-encoding: br`) carry `ETag: W/"fbb8458fccf9d8f0"`. v0.1.0 compares `If-None-Match` exactly against the strong tag, so `W/"…"` gets **200 instead of 304**; a strong tag still gets 304. The member's conditional request (browser, compressed) returned 200. **The live app is affected**: its cached record holds `etag: W/"fbb8458fccf9d8f0"`, so each revalidation re-downloads about 27 KB instead of a 304. Correctness is unaffected (every 200 is validated).
  - **Fix**: backend `f13036a1cc0` (v0.1.1) uses weak comparison per RFC 9110 13.1.2 (lists and `*` included). A new spec fails on the v0.1.0 controller at 28529a6d with exactly `W/"fbb8458fccf9d8f0"` and passes with the fix.
  - Standalone split `07bb7d38065ede03d0ac9f49f4f89d9ae8d4eed3` (`5be3ca9` for the fix, then `07bb7d3` for the README; descends from the published `52cbcad`).
  - **Not published or deployed**: that needs a v0.1.1 tag push and a rebuild with the clone line changed to `--branch v0.1.1`.

### Backend specs at the deployed revision

| Revision | Plugin | Other plugins | Result |
| --- | --- | --- | --- |
| `28529a6d` (deployed) | v0.1.0 (`9b238e291e9` tree) | `fomio_plgin` `1cd3462` (as in production) | 46 examples, 0 failures ([log](28529a6-rspec.log.gz)) |
| `28529a6d` | v0.1.0 controller + v0.1.1 spec | same | 47 examples, **1 failure** (weak-ETag reproduction) |
| `28529a6d` | v0.1.1 (`f13036a1cc0`) | same | 47 examples, 0 failures ([log](28529a6-rspec-weak-etag.log.gz)) |
| `d4296c5` (branch base) | v0.1.1 | — | 47 examples, 0 failures; RuboCop and syntax_tree clean ([log](backend-rspec-weak-etag.log.gz)) |

### Native app against the live site

New opt-in suite `FomioUITests/LiveLocalizationUITests.swift` (`TEST_RUNNER_FOMIO_LIVE_UI_TESTS=1`): `--live`, no fixture, anonymous reads only, a fresh storage namespace per test. To fail only catalog requests in live mode, a Debug-only `--l10n-offline` was added (`OfflineLocalizationTransport`). Community content still loads live, and the simulator's network was not cut.

| Test | iPhone 17 | iPad Pro 11 |
| --- | --- | --- |
| Arabic iOS fresh install → English; Me › Language lists English (selected), no Arabic, no device row; choose English; relaunch keeps English; relaunch with catalog requests offline keeps English | Pass | Pass |
| English iOS, no cache, catalog offline → bundled English | Pass | Pass |
| Live discussion: native Back on the left, tap Back and edge swipe return to the same anchor (±4 pt); Cards persists across relaunch; back to Compact | Pass | Pass |

Commands: `TEST_RUNNER_FOMIO_LIVE_UI_TESTS=1 xcodebuild test-without-building … -only-testing:FomioUITests/LiveLocalizationUITests` → [iPhone log](live-ui-iphone.log.gz), [iPad log](live-ui-ipad.log.gz). The first iPhone attempt failed on a test bug: the `topic-` prefix also matched category chips; it now matches `topic-[0-9]+`. That run is kept as [live-ui-iphone-run1.log](live-ui-iphone-run1.log.gz).

Cache evidence (simulator container, the first test's namespace): `catalog-en.json` revision `fbb8458fccf9d8f0`, `etag W/"fbb8458fccf9d8f0"`, fetched live at 11:04:25. `lastUsedAt` advanced to 11:04:46 during the offline relaunch without a new fetch, so the cached live catalog, not a download, served that launch. A manual fresh install (Arabic iOS) also cached the live index (`"b2201006ba066631"`) and `en`.

Screenshots (inspected): iPhone [1](iphone-live-1-arabic-ios-fresh-install-english-home.jpg) [2](iphone-live-2-me-language-english-from-the-live-index.jpg) [3](iphone-live-3-relaunch-with-catalog-requests-offline-english-kept.jpg) [4](iphone-live-4-english-ios-no-cache-catalog-offline-bundled-english.jpg) [5](iphone-live-5-live-discussion-with-native-back.jpg) [6](iphone-live-6-live-feed-in-cards.jpg); iPad [1](ipad-live-1-arabic-ios-fresh-install-english-home.jpg) [2](ipad-live-2-me-language-english-from-the-live-index.jpg) [3](ipad-live-3-relaunch-with-catalog-requests-offline-english-kept.jpg) [4](ipad-live-4-english-ios-no-cache-catalog-offline-bundled-english.jpg) [5](ipad-live-5-live-discussion-with-native-back.jpg) [6](ipad-live-6-live-feed-in-cards.jpg).

### Regressions on the final source (app with the Debug offline flag and the live suite)

| Run | Result |
| --- | --- |
| iPhone 17 full scheme | 120 unit/contract (4 live skipped) + 55 UI (4 skipped: the older live UI test and the 3 new live tests, which ran opt-in above), **0 failures** ([log](final2-full-iphone.log.gz)) |
| iPad Pro 11: `FomioTests` + Localization, FeedAppearance, ReviewFixes (stable recovered-image counts, retained errors), NavigationDirection UI | 120 (4 live skipped) + 25 UI, **0 failures** ([log](final2-ipad.log.gz)) |

### Live versus fixture-only

Verified **live**: English first launch on English and Arabic iOS, live English listing and selection, persistence across relaunch, cached live catalog with catalog requests offline, bundled English with no cache, Back, edge swipe and anchors, Compact/Cards persistence, member and anonymous HTTP behavior.

**Fixture only** (no approved non-English language live): selecting a non-English language, RTL and Arabic plurals, a removed language with or without a cache, invalid or incomplete catalogs and failed selection. Also fixture only: media failure recovery counts and retained feed errors, which can't be forced on the live site without changing it.

### Remaining gates

- **E3 (merge gate)**: a live non-English language selected in Me › Language. Needs a language approved for `fomio_app_locales`; for Arabic that means **native-speaker review (E4) first**. The allowlist stays `en`.
- **v0.1.1 (recommended before release)**: publish tag `v0.1.1` = `07bb7d38065` and rebuild with the clone at `--branch v0.1.1`. Then rerun `verify-live-catalogs.sh` and a compressed conditional request; expect 304.
- Release-only: E4 native Arabic review, E6 physical-device VoiceOver, E7 terminology agreement.
- Operations (outside this change): rotate the SMTP credential; keep `/shared/postgres_data_old` until the upgraded database is trusted; the droplet reports a pending OS restart.

## Destination identified from project configuration

- Release pipeline: Fomio monorepo `apps/mobile/docs/20-implementation/discourse-plugin-supply-chain-runbook.md` and `scripts/plugin-release.sh`. One standalone public repository per plugin, root = `plugin.rb`, produced by `git subtree split`, `main` and tag `vX.Y.Z` pushed atomically. The server clones it pinned to the tag in `containers/app.yml` `hooks.after_code`, then `./launcher rebuild app`. Rollback means re-pinning or removing the clone and rebuilding. The existing `discourse-fomio-user-shell` plugin is published as the public `ismailzabalawi/fomio_plgin`.
- Planned standalone repository (convention: named after the plugin): `github.com/ismailzabalawi/discourse-fomio-app-locales`, tag `v0.1.0`.
- Host: `meta.fomio.app` resolves to `134.122.67.114`. No project file, SSH configuration, `known_hosts` entry, DigitalOcean CLI configuration or CI workflow on this Mac gives access to it; no SSH user is recorded anywhere. No username was guessed and no unknown host key was trusted.

## Deployed revision and compatibility

- Live generator: Discourse `7b4f0970506fb0ce7d4b6a851d252ace418330c8`; `/srv/status` `ok` ([live-http-2026-10-16.txt](live-http-2026-10-16.txt)).
- A detached worktree of the Discourse checkout at exactly `7b4f0970` (`/Volumes/Develop/Projects/Dicourse-worktrees/deployed-7b4f0970`) was used. It had its own gems (`vendor/bundle`), its own `pnpm install --frozen-lockfile` and a dedicated test database `discourse_test_fomio_7b4f0970`. The plugin was copied in from backend commit `6eca1a33a4a` (`git archive`).
- `RAILS_DB=discourse_test_fomio_7b4f0970 LOAD_PLUGINS=1 bin/rspec plugins/discourse-fomio-app-locales/spec` → **46 examples, 0 failures** ([log](deployed-7b4f0970-rspec.log.gz)).
- Real deployed-code header check: at 7b4f0970, `set_current_user_for_logs` really adds `X-Discourse-Username` for signed-in requests. With the plugin's `prepend_after_action :remove_member_headers` disabled, the signed-in catalog response carried `"X-Discourse-Username" => "catalog_member"` and the example failed. Restored, it passes.
- Disclosure: a first attempt with `TEST_ENV_NUMBER` resolved to the pre-existing local test database `discourse_test_0`. It was migrated with 7b4f0970's migrations, which only adds missing ones; it is a disposable test database. The dedicated database was then used for every result above.

## Publication

- Backend commit `9b238e291e9` adds the release/deployment procedure to the plugin README, on top of `245a6b63e10` and `6eca1a33a4a`.
- Standalone split, built with `git commit-tree` from each plugin commit's subtree, preserving author, committer, dates and message (equivalent to `git subtree split --prefix=plugins/discourse-fomio-app-locales`, which was too slow over Discourse's full history):
  - `245a6b63e10` → `3501589cdcea41c234a80ed31401afc751ebbd1b`
  - `6eca1a33a4a` → `5a5b546828e538d1d982729acd53600dbf887cdf`
  - `9b238e291e9` → **`52cbcad6aef4020aef3138e3bda35d83acaa95e9`** (root: `README.md app catalogs config lib plugin.rb spec`; tree identical to `plugins/discourse-fomio-app-locales` at `9b238e291e9`)

### Published 2026-10-16 (user-approved public repository)

- Before publishing: the split tree equals `plugins/discourse-fomio-app-locales` at `9b238e291e9`. It holds only the plugin's 13 files: README, controller, catalogs en/ar/manifest, server locale, routes, settings, builder, engine, `plugin.rb` and two specs. A secret pattern scan (keys, tokens, passwords, private keys, emails, host IP) found nothing. Commit author metadata is the same as on the already-public `Fomio.app` repository.
- `gh repo create ismailzabalawi/discourse-fomio-app-locales --public` → https://github.com/ismailzabalawi/discourse-fomio-app-locales (it did not exist before).
- `git push --atomic … 52cbcad…:refs/heads/main 52cbcad…:refs/tags/v0.1.0`. `git ls-remote` shows `HEAD`, `refs/heads/main` and `refs/tags/v0.1.0` all at `52cbcad6aef4020aef3138e3bda35d83acaa95e9`.
- The server's exact install command, run anonymously (`git clone --branch v0.1.0 --depth 1 https://github.com/ismailzabalawi/discourse-fomio-app-locales.git`, no credential helper), checked out `52cbcad`. `diff -r` against the backend plugin directory found no differences; `plugin.rb` is version 0.1.0.
- Live after publication: unchanged, 404 at 7b4f0970 ([verify-after-publication.txt](verify-after-publication.txt)).

## Live app verification (against the real endpoint; no fixture)

Debug build from `2dda70b`'s source, launched without `--fixture`, so it uses `FomioBaseURL` `https://meta.fomio.app` and the configured catalog paths. Fresh install on iPhone 17 / iOS 26.1 with `-AppleLanguages (ar) -AppleLocale ar_SA`; guest.

| Check | Live result |
| --- | --- |
| Fresh launch on an Arabic device | English interface with live community content ([live-1](live-1-arabic-ios-fresh-install-english-home.jpg)) |
| Me › Language with the endpoint returning 404 | English only, checked; "Other languages aren't available from this community yet." ([live-2](live-2-language-english-only-endpoint-404.jpg)) |
| Explicit non-English selection, RTL, plurals, relaunch, offline cache, removed or invalid live catalog | **Not possible live**: no endpoint is deployed, and no non-English language is approved for `fomio_app_locales` |

## Reruns (2026-10-16)

| Run | Source | Result |
| --- | --- | --- |
| iPhone 17, full scheme (simulator rebooted first) | app `68eb442` (app source identical to `2dda70b`) | 120 unit/contract (4 live skipped) + 52 UI (1 live skipped), **0 failures** ([log](rerun-full-iphone.log.gz)) |
| iPad Pro 11, `FomioTests` + `LocalizationUITests`, `FeedAppearanceUITests`, `ReviewFixesUITests`, `NavigationDirectionUITests` | same | 120 unit/contract (4 live skipped) + 25 UI, **0 failures** ([log](rerun-ipad.log.gz)); includes Back/edge-swipe/anchor, stable recovered-image attempt counts and retained-error regressions |
| Backend plugin on `d4296c5` | backend `9b238e291e9` | 46 examples, 0 failures ([log](backend-rspec-9b238e2.log.gz)) |
| Backend plugin on deployed `7b4f0970` | plugin from `6eca1a33a4a` (`9b238e291e9` changes only the README) | 46 examples, 0 failures |

These are fixture/simulator results; they do not prove the live connection. After publication no app or plugin source changed: app code is unchanged since `2dda70b`, and the published tree is byte-identical to the tested plugin directory. The reruns above therefore remain the current evidence and were not repeated. Anything affected by an actual installation (live HTTP, live app selection) must be rerun after deployment.

## Additional readiness checks (2026-10-16, read-only)

- Access recheck 09:00 UTC: no SSH configuration, host key or agent identity on this Mac (unchanged). Remote `main` and `v0.1.0` still at `52cbcad`.
- Live recheck 08:57 UTC: generator 7b4f0970, `/srv/status` ok, catalog paths 404 ([verify-recheck.txt](verify-recheck.txt)).
- Installed plugins visible publicly (JS assets): checklist, details, lazy-videos, local-dates, presence, reactions, solved, templates, topic-voting, poll, spoiler-alert. All are core plugins at 7b4f0970.
- Route coexistence: the unversioned local plugin `discourse-fomio-api` mounts an engine at `/fomio`. It is evidently not deployed (anonymous JSON `/fomio/me/activity.json` returns Discourse's generic not-found; a login-required route would answer 403). Installed together at 7b4f0970, its `/fomio` engine is routed before `/fomio/app-locales`, and all 46 of this plugin's examples still pass. Its own 3 failing examples are unrelated ([log](coexist-fomio-api-7b4f0970-rspec.log.gz)). The temporary copy was removed.
- Rebuild version risk: a rebuild installs `app.yml`'s `version` (default `tests-passed` = `f3758bd5a69` on 2026-10-16, 1,745 commits after 7b4f0970). The plugin's dependencies (skipped callbacks, `JsLocaleHelper.translations_for`, `LocaleSiteSetting`, `Rtl::LOCALES`) exist at all three revisions. In a detached checkout at `f3758bd5a69` (own gems, pnpm, database `discourse_test_fomio_f3758bd`, plugin from `9b238e291e9`): **46 examples, 0 failures** ([log](rebuild-candidate-f3758bd-rspec.log.gz)). The console procedure still recommends pinning 7b4f0970, so no unrelated upgrade is bundled.
- The discourse_docker `launcher` source (fetched read-only) confirms `start-cmd` is a read-only parse, and that `rebuild` keeps the old container until bootstrap succeeds, so `./launcher start app` restores service after a failed bootstrap.
- [console-install.md](console-install.md): step-by-step console procedure with backup, version pin, single-line hook change, health checks and rollback.

## Console session (2026-10-16 09:01 UTC)

The user opened the DigitalOcean droplet web console (root shell, hostname `meta`, 134.122.67.114, as shown in its banner) in the in-app browser and asked the agent to deploy through it. The agent could not operate it: the agent permission classifier refused input to the production root shell, and the browser tooling refuses to drive the console because it is a page-opened popup. **No command was typed or run on the host** (the console still showed only the login banner and prompt). Neither control was worked around.

## Post-deployment verification script

[`verify-live-catalogs.sh`](verify-live-catalogs.sh) is read-only. It checks:
- `/srv/status` and the generator revision;
- index and `en` return 200, are complete, have an ETag, a conditional request returns 304, and `Cache-Control` is public;
- no `X-Discourse-Username` on 200 or 304;
- `xx`, schema 2 and `AR` return 404;
- member checks only when `FOMIO_MEMBER_API_KEY` and `FOMIO_MEMBER_USERNAME` are set in the environment. A per-user key is sent only as a header and never printed; the member body must equal the anonymous body and must not contain the username.

Pre-deployment run: [verify-predeploy.txt](verify-predeploy.txt). The 404 negative checks and `/srv/status` pass; the endpoint checks fail as expected.

## Blockers

1. ~~Publish the standalone repository~~: done 2026-10-16 (see above).
2. **Install on the meta.fomio.app host.** Update 09:01 UTC: console access exists (user-opened DigitalOcean web console), but the agent may not operate it. A person runs [console-install.md](console-install.md) there, or explicitly permits the agent to drive the console as a regular (non-popup) tab. Earlier note: Rechecked 2026-10-16: this Mac's `~/.ssh` has no `config`, `known_hosts`/`known_hosts.old` contain only `github.com`, the SSH agent has no identities, and no project file names a host user. Needed, from the person who administers the droplet, either:
   - an SSH user for `134.122.67.114` whose authorized keys include this Mac's key (or a key added to the agent), **plus the host's SSH key fingerprint, obtained out of band** (for example from the DigitalOcean droplet console: `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`), so the first connection can be verified rather than trusted blindly; or
   - that person running the steps below in the droplet's web console.

   Steps:
   ```
   cd /var/discourse
   cp containers/app.yml containers/app.yml.before-fomio-app-locales
   # add under hooks.after_code → exec (cd: $home/plugins) → cmd, next to the existing clones:
   #   - git clone --branch v0.1.0 --depth 1 https://github.com/ismailzabalawi/discourse-fomio-app-locales.git
   ./launcher rebuild app
   ```
   Before editing, check the existing hooks and which plugins are installed, and that the image is still at 7b4f0970. After the rebuild, `/srv/status` should return `ok`. Rollback: restore the backup and rebuild, or set `fomio_app_locales_enabled` to false.
3. **Then** run `verify-live-catalogs.sh`, anonymously and with a member's own per-user key, and repeat the live app checks.
4. **E3** additionally needs a non-English language approved for `fomio_app_locales`. Arabic requires native-speaker review (E4) first; deployment authorization is not that approval. Arabic stays disabled (`fomio_app_locales = en`).
