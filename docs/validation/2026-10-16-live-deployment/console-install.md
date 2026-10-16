# Installing discourse-fomio-app-locales on meta.fomio.app (droplet console)

For the person with shell access to `134.122.67.114` (standard `/var/discourse` install). Prepared 2026-10-16. Nothing here changes site settings, content or other plugins. Expected downtime: the length of one rebuild (typically several minutes).

## Host facts seen in the droplet console banner (2026-10-16 09:01 UTC)

Ubuntu 22.04.5 LTS, DigitalOcean Discourse 1-Click, IPv4 134.122.67.114, `/` 39.1% of 154.88 GB used, load 0.21, memory 48%. The banner also says **"System restart required"**: unrelated to this plugin. Do not reboot as part of this change.

## What the public site shows (read-only, 2026-10-16)

- Discourse `7b4f0970506fb0ce7d4b6a851d252ace418330c8`; `/srv/status` `ok`.
- Plugins with public JS: checklist, details, lazy-videos, local-dates, presence, reactions, solved, templates, topic-voting, poll, spoiler-alert. **All of these ship inside core at 7b4f0970**, so `app.yml` probably clones only `docker_manager`. Server-only plugins aren't visible publicly, so step 1 checks.
- `/fomio/...` is unused (the unversioned `discourse-fomio-api` is evidently not installed). If it is installed later, both coexist: tested at 7b4f0970.

## 1. Read before changing anything

```
cd /var/discourse
df -h /                                                     # a rebuild needs a few GB free
grep -n -E '^\s*version:' containers/app.yml                # see step 3
grep -n -A15 'after_code:' containers/app.yml               # the existing plugin clones
git ls-remote https://github.com/ismailzabalawi/discourse-fomio-app-locales.git refs/tags/v0.1.0
#   expect: 52cbcad6aef4020aef3138e3bda35d83acaa95e9  refs/tags/v0.1.0
```

## 2. Back up

```
cp containers/app.yml containers/app.yml.before-fomio-app-locales
```

A site backup (Admin › Backups, or `./launcher enter app` then `discourse backup`) is recommended. The plugin has no migrations, but a rebuild can also change the Discourse version (step 3), and core migrations can't be undone without a backup.

> Outcome 2026-10-16: no pin was in effect. The rebuild upgraded Discourse (and PostgreSQL from 15), and the user then chose to keep Discourse **unpinned** for normal upgrades. To change the clone tag, replace `--branch v0.1.0` with the new tag and rebuild. See the deployment record.

## 3. Decide the Discourse version for this rebuild

A rebuild installs whatever `params: version:` names (default `tests-passed`). On 2026-10-16 `tests-passed` is `f3758bd5a69`, **1,745 commits newer** than the running 7b4f0970.

- **Recommended: change only the plugin.** Under `params:` set `version: 7b4f0970506fb0ce7d4b6a851d252ace418330c8` (or keep an existing pin). The plugin's 46 specs pass at exactly this revision. Upgrading Discourse is then a separate decision; remove the pin when you do.
- Or upgrade together: leave `tests-passed`. The plugin's 46 specs also pass at `f3758bd5a69` (Ruby 3.4.7 locally; the image may use Ruby 4.0, which wasn't tested). Compatibility alone doesn't authorize a platform upgrade.

## 4. Add the plugin clone

In `hooks: after_code: - exec: cd: $home/plugins  cmd:`, add one line after the existing clones and change nothing else:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/discourse/docker_manager.git        # existing line(s), unchanged
          - git clone --branch v0.1.0 --depth 1 https://github.com/ismailzabalawi/discourse-fomio-app-locales.git
```

Check the file still parses, then compare with the backup. The diff should show only the clone line (and the version pin, if chosen):

```
./launcher start-cmd app > /dev/null && echo "app.yml parses"      # read-only
diff containers/app.yml.before-fomio-app-locales containers/app.yml
```

## 5. Rebuild and check health

```
./launcher rebuild app
curl -s https://meta.fomio.app/srv/status                                   # ok
curl -s https://meta.fomio.app/ | grep -o 'version [0-9a-f]\{40\}'          # the version chosen in step 3
./launcher logs app 2>&1 | tail -50                                         # no boot errors
```

Admin › Plugins should list `discourse-fomio-app-locales` 0.1.0. Admin › Settings, filter `fomio_app_locales`: `fomio_app_locales_enabled` true and `fomio_app_locales` `en`. **Leave them at those values.** Adding another language needs its recorded native-speaker review first. Don't change web interface languages, `allow_user_locale` or content translation.

## 6. Verify (from the Mac, read-only)

```
docs/validation/2026-10-16-live-deployment/verify-live-catalogs.sh
```

Then once more with a member's own per-user key in `FOMIO_MEMBER_API_KEY` and `FOMIO_MEMBER_USERNAME` (environment only, never an admin key, never written to a file).

## Rollback

- **If `./launcher rebuild app` fails during bootstrap** (for example a clone or asset error): the launcher stops the old container before bootstrapping and removes it only after a successful bootstrap, so the old one still exists. `./launcher start app` restarts the previous site. Then fix or revert `app.yml` before rebuilding again (from the discourse_docker `launcher` source, 2026-10-16).
- **Immediate, no rebuild:** set `fomio_app_locales_enabled` to false. Every catalog route then returns 404, and the app keeps English, its built-in fallback.
- **Remove the plugin:** `cp containers/app.yml.before-fomio-app-locales containers/app.yml && ./launcher rebuild app`. The plugin stores no data, so there is nothing to clean up. If the rebuild in step 5 also upgraded Discourse, the restored file no longer pins the old version. Pin it (step 3), and restore the backup from step 2 if the core upgrade itself must be undone.
