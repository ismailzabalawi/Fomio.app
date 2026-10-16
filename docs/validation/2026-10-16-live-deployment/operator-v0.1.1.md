# Operator steps: upgrade discourse-fomio-app-locales v0.1.0 → v0.1.1 on meta.fomio.app

Run in the droplet console as root. It changes **one line** of `containers/app.yml` and rebuilds; nothing else.
Discourse stays unpinned (the rebuild may also bring Discourse up to date, as you chose). Other plugins, settings,
the `en` allowlist and `/shared/postgres_data_old` are untouched.

**Don't paste** `app.yml`, `start-cmd` output or the rebuild log anywhere: they contain the container's environment, including credentials.

```bash
cd /var/discourse
TS=$(date +%Y%m%d%H%M%S); umask 077

# 1. Non-overwriting backup
cp -n containers/app.yml "containers/app.yml.before-fomio-app-locales-v0.1.1-$TS" && echo "backup: containers/app.yml.before-fomio-app-locales-v0.1.1-$TS"

# 2. Preconditions: exactly one clone line, at v0.1.0; the published tag is the reviewed commit
grep -c 'discourse-fomio-app-locales' containers/app.yml                       # expect 1
grep -o -- '--branch v0\.1\.[0-9]* --depth 1 https://github.com/ismailzabalawi/discourse-fomio-app-locales\.git' containers/app.yml   # expect v0.1.0
git ls-remote https://github.com/ismailzabalawi/discourse-fomio-app-locales.git refs/tags/v0.1.1   # expect 07bb7d38065ede03d0ac9f49f4f89d9ae8d4eed3

# 3. The one-line change, then check it
sed -i 's#--branch v0\.1\.0 --depth 1 https://github.com/ismailzabalawi/discourse-fomio-app-locales\.git#--branch v0.1.1 --depth 1 https://github.com/ismailzabalawi/discourse-fomio-app-locales.git#' containers/app.yml
grep -o -- '--branch v0\.1\.[0-9]* --depth 1 https://github.com/ismailzabalawi/discourse-fomio-app-locales\.git' containers/app.yml   # expect v0.1.1
diff "containers/app.yml.before-fomio-app-locales-v0.1.1-$TS" containers/app.yml | grep -c '^[<>]'   # expect 2 (one line out, one in)
./launcher start-cmd app >/dev/null 2>&1 && echo "app.yml parses"

# 4. Rebuild; output only to a root-only file
./launcher rebuild app > "/root/rebuild-fomio-app-locales-v0.1.1-$TS.log" 2>&1; echo "rebuild exit $?"
curl -s https://meta.fomio.app/srv/status; echo
```

Expected: `rebuild exit 0`, then `ok`. Then tell Claude, which verifies from outside (read-only).

## If something goes wrong

- **Step 2 or 3 doesn't show the expected value:** stop. Restore with `cp "containers/app.yml.before-fomio-app-locales-v0.1.1-$TS" containers/app.yml`. Nothing was rebuilt.
- **`rebuild exit` isn't 0 and the site is down:** run `./launcher start app >/dev/null 2>&1` first. The launcher keeps the old container until the new bootstrap succeeds, so this restores the previous site. Exception: the rebuild may stop deliberately after a PostgreSQL upgrade ("rebuild again"); then run `./launcher rebuild app` once more. Report only the last lines that **don't** contain `docker run`.
- **Back to v0.1.0:** restore the backup and rebuild. The plugin stores no data.
- **Stop the endpoints without a rebuild:** Admin › Settings, `fomio_app_locales_enabled` = false. The app keeps English.
