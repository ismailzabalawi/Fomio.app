# Live deployment of discourse-fomio-app-locales: preparation, deployed-revision verification, blockers

Date 2026-10-16 (Amman; UTC 2026-10-15 22:30–23:00). App branch `claude/fomio-localization-impl-48ecab` (app source unchanged since `2dda70b`). Backend branch `fomio/app-locale-catalog`. `main` (`b62aef5`, build 0.8.0 (5)) untouched; nothing merged.

**Result: the plugin is not deployed yet. E2 and E3 remain open.** Everything up to publication is done and verified against the deployed Discourse revision. Two concrete actions remain; see [Blockers](#blockers).

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

## Publication prepared (not pushed)

- Backend commit `9b238e291e9` adds the release/deployment procedure to the plugin README, on top of `245a6b63e10` and `6eca1a33a4a`.
- Standalone split, built with `git commit-tree` from each plugin commit's subtree, preserving author, committer, dates and message (equivalent to `git subtree split --prefix=plugins/discourse-fomio-app-locales`, which was too slow over Discourse's full history):
  - `245a6b63e10` → `3501589cdcea41c234a80ed31401afc751ebbd1b`
  - `6eca1a33a4a` → `5a5b546828e538d1d982729acd53600dbf887cdf`
  - `9b238e291e9` → **`52cbcad6aef4020aef3138e3bda35d83acaa95e9`** (root: `README.md app catalogs config lib plugin.rb spec`; tree identical to `plugins/discourse-fomio-app-locales` at `9b238e291e9`)

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

These are fixture/simulator results; they do not prove the live connection.

## Post-deployment verification script

[`verify-live-catalogs.sh`](verify-live-catalogs.sh) is read-only. It checks:
- `/srv/status` and the generator revision;
- index and `en` return 200, are complete, have an ETag, a conditional request returns 304, and `Cache-Control` is public;
- no `X-Discourse-Username` on 200 or 304;
- `xx`, schema 2 and `AR` return 404;
- member checks only when `FOMIO_MEMBER_API_KEY` and `FOMIO_MEMBER_USERNAME` are set in the environment. A per-user key is sent only as a header and never printed; the member body must equal the anonymous body and must not contain the username.

Pre-deployment run: [verify-predeploy.txt](verify-predeploy.txt). The 404 negative checks and `/srv/status` pass; the endpoint checks fail as expected.

## Blockers

1. **Publish the standalone repository** (authorized by the user; blocked in this session by the agent permission classifier as "create public surface", so not attempted further). From the backend worktree:
   ```
   gh repo create ismailzabalawi/discourse-fomio-app-locales --public --description "Public read-only interface catalogs for the Fomio native app"
   git push --atomic https://github.com/ismailzabalawi/discourse-fomio-app-locales.git 52cbcad6aef4020aef3138e3bda35d83acaa95e9:refs/heads/main 52cbcad6aef4020aef3138e3bda35d83acaa95e9:refs/tags/v0.1.0
   ```
   A lightweight tag matches the split SHA. An annotated tag (`git tag -a v0.1.0 52cbcad…`) is equally fine; the tag must never be moved later.
2. **Install on the meta.fomio.app host** (needs someone with shell access to `134.122.67.114`, or the console of its hosting provider):
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
