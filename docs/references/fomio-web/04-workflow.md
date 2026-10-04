# 04 — Workflow

**2026-10-01, subsequent authorization:** Ismail explicitly authorized enabling
the newer composer on the remote site. The native admin Upcoming Changes API
accepted `enable_composer_redesign=true` (`200`, `success: OK`). Browser
verification confirmed the native layout class in theme 36 and rendered
category → Public → title → editor with the bottom Format toolbar. This is a
site-wide change, including the default theme; theme watch still targets 36.
Earlier notes below saying this setting was left disabled are historical.


## Live development

**Current session, 2026-10-01:** Ismail rates the visual result at about 80%
and explicitly requested stopping the local server and using Discourse watch
for testing on theme **36**. The current working tree was uploaded to 36 and
one fresh `discourse_theme watch .` is running (PID 76188 at start; verify
process state rather than assuming this PID persists). The previous watcher
in this same directory was stopped first. Read-only remote verification
confirmed theme **31** is still the default. Future theme-code saves in this
folder now upload to theme 36 automatically.

The isolated local Rails/Puma server on 4300, frontend builder, private
PostgreSQL and Redis services were stopped; their data/files were retained.
Use `https://meta.fomio.app/?preview_theme_id=36` for review. After reload,
DOM metadata confirmed theme 36, but the native `uc-enable-composer-redesign`
class was absent. No site-wide composer setting was changed. The newer
layout's activation on the remote site remains a separate action; theme
watch by itself does not enable it. The visual design is still in progress,
not signed off. Older dated local-only statements below are historical.


**2026-09-29 composer experiment:** theme 36 was the live default at the
latest check. Its stored upload/watch target has not changed. The opt-in
composer was uploaded explicitly to non-default theme **38**, not 36; see
[11](11-composer-native-feasibility.md). Re-check the default before uploading.

**2026-09-30:** a `discourse_theme watch .` started 2026-09-26 was found still
running while theme 36 was the site default, so every save in this folder
went to visitors, including uncommitted work (07, Phase 4). Check
`ps -axo command | grep discourse_theme` before editing, not only the default.
The user has since restored theme 31 as the site default. The watcher remains
mapped to theme 36; confirm the current default and watcher before any further
theme edits or uploads.

```bash
cd ~/"Projects/Rebuilding Discourse/fomio-web"
discourse_theme watch .        # the DIR argument is required
```

- The `discourse_theme` gem (2.1.6) is installed. Its config lives in
  `~/.discourse_theme` (YAML). An API key for `https://meta.fomio.app` is
  already stored there, so only the site URL is asked for on first run.
- **Security follow-up (2026-09-26):** a local automation tool printed this
  configuration while testing. Treat the Meta API key as exposed, rotate it,
  and update the local configuration afterward. Do not record the key in this
  repository, documentation, chat, or tool output. The user acknowledged this
  and plans to rotate the key later (2026-09-30).
- This directory is uploaded as **theme id 36**. It was created by `watch`,
  **not** installed from git, so it isn't linked to the GitHub repo.
- **Theme 36 is an isolated preview again as of 2026-09-27**: the user
  restored theme 31 as the site default. Every `watch` save reaches theme 36,
  not visitors; use `?preview_theme_id=36` to inspect it. Its palettes: light
  "Fomio" (36), dark "Fomio AMOLED" (38).
  A member's own palette preference overrides the theme's (the admin account
  has dark scheme 32).
  **Re-checked later on 2026-09-27** (read-only `/admin/themes.json`): theme
  **31** was the default again, and a plain page load rendered theme 31. Check
  the default before assuming a save is live; preview with
  `?preview_theme_id=36` whenever 36 isn't the default.
- Signed-out checks: a fresh headless Chromium profile (no cookies) sees
  what a visitor sees. Playwright's cached `chrome-headless-shell` is on this
  machine; never sign the user out of their browser to check.
- Every save pushes to the server. After a JS change, hard-refresh.
- While `watch` runs, the preview's message-bus poll has returned
  `429 Too Many Requests`. That's server rate-limiting, not the theme.

## Before every commit

```bash
./scripts/check-native.sh      # no hex/rgb literals in SCSS; no Hub/Teret/Byte (dropped naming) in theme code
./scripts/check-variables.sh   # every custom property set or read exists in core (R3)
./scripts/check-scss.sh        # compiles against a stub of core's viewport module
./scripts/check-duplication.sh # no theme HTML fields; outlets and panels only from its allowlist
```

- **check-variables.sh** reads a Discourse checkout (`DISCOURSE_SRC`, default
  `~/Projects/Fomio/discourse`). It scans core stylesheets, bundled plugins and
  `lib/stylesheet/*.rb`, and skips with a warning if there's no checkout. CSS
  ignores unknown custom properties without an error, so a dead rule looks
  like a working one. This is the only check that catches that.
  **The checkout is 2026-03-09; the server is 2026.8.0**, and the difference is
  load-bearing — see the `ui-kit` note in 02. Don't run the guards against the
  checkout: export the server's commit first and point `DISCOURSE_SRC` at it.
  The commit is already in the checkout, so the export is offline and writes
  nothing to that read-only repo.
  **An export under `/tmp` doesn't last:** on 2026-09-27 the day-old
  `/tmp/discourse-7b4f0970` had lost most of `frontend/…/helpers/` and
  `lib/`, which made present modules look missing. Re-export before relying
  on it, or export into a session scratch folder. The exact commands are in 02, under *Source
  and version*. `check-variables.sh` prints which source it used, so the claim
  is checkable in its output.
- **check-scss.sh** compiles against a stub of core's `lib/viewport` module (`from` and `until`; `until` added 2026-09-26 when `common.scss` first used it, written as core's exclusive `width < breakpoint` — an inclusive `max-width` would also match exactly 640px, where core's rules stop)
  (and the theme settings, once `settings.yml` returns). It doesn't know
  every core module; a new `@use` needs a stub.
- **check-duplication.sh** guards against inserting a design instead of
  restyling core — the first theme's failure, where a design's header or nav
  rendered beside Discourse's. It fails on any `*.html` in
  `common/desktop/mobile`, a `connectors/` folder, an outlet or sidebar panel
  not on its allowlist, or a replaced core header/list/sidebar component.
  The allowlist is empty after the restart; adding to it is a decision,
  recorded in 03.
- None of the guards check that a selector matches core's DOM. That still
  needs reading core (02) and looking at the page.

## Theme tests

`test/acceptance/*-test.js` are QUnit acceptance tests against core's
fixtures. **They can't run on meta.fomio.app:** `/theme-qunit?id=36` answers
that a production installation can't be used for theme testing (checked
2026-09-26). Run them on a development Discourse at the server's commit.

## Verifying visually

- **Screenshots from the user work.** This is what verified the feed row.
- **Chrome extension (`mcp__claude-in-chrome__*`)** can read the DOM and
  computed styles, which beats pixels. In this session `tabs_context_mcp`
  timed out repeatedly and never returned a tab.
- **computer-use** needs macOS Screen Recording and Accessibility for the
  **exact Claude Code binary**,
  `~/.local/share/claude/versions/<version>`. Each Claude Code update is a new
  binary and needs granting again, which is why stale entries like `2.1.220`
  pile up in the list. Check the running version with `ps -o command -p $PPID`.

What to check on each visual pass: the launch-journey step the change serves,
phone width below 640px, signed out as well as signed in, and light and dark
palettes.

## Shipping

- Repo: `git@github.com:ismailzabalawi/fomio-web.git`, private, branch `main`.
- **`fomio-web/` is the only working copy.** Run git from inside it. Never
  make `Rebuilding Discourse/` (or any parent folder) a git repo pointing at
  this remote: git records `fomio-web/` as a gitlink — a nested-repo pointer
  with no `.gitmodules`, which GitHub can't resolve — and a merge copies the
  theme to the parent's root. That happened once (`f9c935f`, `edfab7a`) and was
  cleaned up in `3800939`. If `git ls-files -s | grep '^160000'` prints
  anything, it has happened again.
- Commit only when the user asks. End messages with the Co-Authored-By line.
  The repo's local git config sets the identity (2026-09-26):
  `Ismail Zabalawi <ismaelzabalawi@hotmail.com>` (note: *ismael*). Commits before that carry a
  machine-generated address (`@…macbook-pro-3.home` / `.local`); `8bb55b7`
  is one and is pushed, so it stays as it is.
- To have Discourse track the repo: **Admin → Customize → Themes → Install →
  From a git repository** with the SSH URL. Because the repo is private,
  Discourse generates a key; add it under the repo's **Settings → Deploy keys**
  (read-only). That creates a new theme, separate from id 36. Not done yet.

## Commit history

Newest last. `git log --oneline --graph` is the authority; this table
records what each step was for.

| Commit | Content |
|---|---|
| `1f40f50` | Token foundation, three settings, tier 4 mapping, feed row, the three guards |
| `f9c935f` | Route inventory, committed from the parent folder (the nested-repo mistake) |
| `edfab7a` | Merge of that parent-folder commit, which brought in a gitlink |
| `eac7fa7` | `docs/` and `CLAUDE.md`; corrected the density comment |
| `9360fb2` | Merge of GitHub `main` into `fomio-web/` |
| `3800939` | Gitlink removed; route inventory moved to `docs/route-inventory.md` |
| `346b93b` | The single-working-copy rule and this table |
| `0c4e2c4` (branch `sidebar-pass`, unpushed) | Sidebar pass; tier 4 on `:root, body`; full border values; docs |
| … → `d474710` | Category header, nav tabs, topic page, onebox, feed-row fixes |
| `archive/v0` (branch, local) | Points at `d474710`: the whole first pass, kept for reference |
| next | **Restart**: skeleton, docs rewritten around the roadmap (00) |

### Background agents and the single working copy

A background Claude job has to isolate its edits in a git worktree. Put that
worktree **outside** the repo, in the job's temp folder, never under
`fomio-web/`. That rules out the nested-repo mistake. Commit on a feature
branch locally, then `git worktree remove` it: git won't let `fomio-web/`
switch to a branch that another worktree has checked out. To watch unmerged
work live without committing on `main`, copy it in as uncommitted changes:
`git diff main <branch> --binary | git apply`.
