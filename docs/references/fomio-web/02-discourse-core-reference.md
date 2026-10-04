# 02 — Discourse core reference

> **After the restart (2026-09-26):** the facts stand, but sections about the
> sidebar, the stacked list row, bulk select and preferences describe what the
> archived v0 code needed. No current code depends on them.

Facts verified by reading core source, with paths so they can be re-checked.
**Never write a variable name, selector or transformer from memory or from a
schema's shorthand** — that is how dead rules got into this theme twice.

## Source and version

- Local checkout: `~/Projects/Fomio/discourse` (read-only). Commit
  `b2d5dcd89`, dated **2026-03-09**, roughly 2026.3 — **3103 commits behind
  the server**. Leave it where it is. It is not parked on a stray edit: it
  sits on the branch `codex/fomio-user-shell-plugin` with an untracked
  `plugins/discourse-fomio-user-shell/` working tree, and the `.gitignore`
  edit is that plugin's un-ignore line. Moving or cleaning it would disturb
  another project's work in progress, and the export below makes it
  unnecessary.
- The server runs **2026.8.0-latest**, commit `7b4f0970`. That commit *is* in
  the local checkout, so a **full-tree export** needs no network and no write
  to the read-only checkout:

  ```bash
  git -C ~/Projects/Fomio/discourse archive --format=tar -o /tmp/core.tar 7b4f0970
  mkdir -p /tmp/discourse-7b4f0970 && tar -xf /tmp/core.tar -C /tmp/discourse-7b4f0970
  export DISCOURSE_SRC=/tmp/discourse-7b4f0970
  ```

  The sidebar and topic-page sections below are verified against that export,
  as is the onebox hero (2026-09-22). Other line numbers are still from the
  old checkout — re-check them against the export before new work.

  The export is the **only** source the guards should see. Running
  `check-variables.sh` against the old checkout is not merely stale: it knows
  564 custom properties where the server defines 765, so a property that is
  perfectly valid on the server can read as invented.
- **The gap between the two is not cosmetic.** At `b2d5dcd89` there is no
  `frontend/discourse/app/ui-kit/` directory at all and `d-icon` lives at
  `discourse/helpers/d-icon`; at `7b4f0970` the helper is
  `frontend/discourse/app/ui-kit/helpers/d-icon.js`. Both theme components
  import from `discourse/ui-kit/helpers/…`, which is right for the server and
  looks wrong against the old checkout. Always verify imports against the
  export.
- Frontend lives under `frontend/discourse/app/`, not
  `app/assets/javascripts/`.

## Routes and feeds

| Fact | Where |
|---|---|
| `Discourse.filters` = `latest unread new unseen top read posted bookmarks hot` | `lib/discourse.rb:313` |
| `anonymous_filters` = `latest top categories hot` — signed-out visitors get a full cross-community feed | `lib/discourse.rb:317` |
| `/filter` route exists | `config/routes.rb:1406` (`list#filter`) |
| `?f=tracked` filters any list to tracked categories — a native "my communities" feed | `lib/topic_query.rb:466,978` |
| `/hot` ranks by `(likes − 1) / (age_hours + 2)^gravity` | `app/models/topic_hot_score.rb` |
| Tabs and homepage both come from the `top_menu` site setting. It has no `tracked` value, so "my communities as home" is not native | site setting |

## Variables — foundation

| Variable | Default | Where |
|---|---|---|
| `--d-border-radius` | `4px` | `app/assets/stylesheets/common/foundation/base.scss:8` |
| `--d-border-radius-large` | `calc(var(--d-border-radius) * 2)` | same, `:9` |
| `--d-nav-pill-border-radius` | `var(--d-border-radius)` | same, `:10` |
| `--d-input-border-radius` | `var(--d-border-radius)` | same, `:11` |
| `--d-content-background` | `initial` | same, `:12` |
| `--space` … `--space-12` | 4px grid (`--space: 0.25rem`) | same, `:15–28` |
| `--font-up-1` … | `1.1487em` (2^(1/5)), **em** — compounds when nested | `common/font-variables.scss:14` |
| `lib/viewport` | `@use "lib/viewport"`, `viewport.from(md)`, `viewport.until(sm)` | `app/assets/stylesheets/lib/viewport.scss` |

Changing `--d-border-radius` alone restyles buttons, inputs and menus.
Verified on the live site.

## Variables — colour (compiled per palette)

In `app/assets/stylesheets/color_definitions.scss`:

- `--d-selected` (`:18`), `--d-selected-hover` (`:19`), `--d-hover` (`:20`)
- The primary ramp: `--primary-very-low`, `-low`, `-low-mid`, `-medium`,
  `-high`, `-very-high` (`:30–35`), plus `-rgb` variants
- `--d-link-color: var(--tertiary)` (`:136`)
- `--title-color--read: var(--primary-medium)` (`:137`),
  `--title-color: var(--primary)` (`:144`)

Test fixtures in `qunit-custom.scss` also define these. Don't treat a hit there
as proof.

## Variables — emitted from Ruby, not stylesheets

`lib/stylesheet/importer.rb`, generated from site settings:

- `--font-family` (`:52`) from `base_font`
- `--heading-font-family` (`:62`) from `heading_font`

A stylesheet-only search misses these. `check-variables.sh` scans this file
for that reason.

## Core's token layer and upcoming changes (2026.8, `7b4f0970`)

- `common/tokens.scss` defines `--token-*` variables on `:root`, and many core
  defaults now point at them: `--token-color-text-default` = `--primary-900`,
  `-text-subtle` = `--primary-800`, `--token-color-surface-hovered` =
  `--primary-100`, `-surface-selected` = `--d-selected`,
  `--token-color-border-default` = `--primary-low`, radii 2/4/8/9999px,
  weights 650/600/500. **600 and 650 aren't served under T6** (400 and 700
  only), so wherever core uses them the theme sets 700.
- **Upcoming changes set variables on `<body>`.** `controllers/application.js`
  (`upcomingChangeBodyClasses`) adds `uc-<setting>` classes to body, and files
  under `common/upcoming-changes/` declare variables on
  `:where(.uc-…)`. A body declaration beats an inherited `:root` value, so a
  theme block on `:root` alone **loses** wherever one is enabled.
  `uc-modernize-foundation-theme` is on for meta.fomio.app and sets button,
  input, sidebar and topic-list variables. The theme's tier-4 block is
  therefore declared on `:root, body`.
- `--d-button-default-border` and `--d-input-border` are consumed as a full
  `border:` value (`d-editor.scss:39`, `select-kit.scss:34`, core default
  `1px solid var(--input-border-color)` in `discourse.scss:11`). A bare colour
  renders no border.

## Shell facts (verified against `7b4f0970`, 2026-09-26)

The live site's `generator` meta tag still reads `7b4f0970` on this date.

| Fact | Where |
|---|---|
| Nav pills read `--d-nav-color`, `-bg-color`, `--hover`, `--active` variants; `nav-active` draws an `::after` underline `--d-nav-underline-height` tall in `--d-nav-color--active` | `common/components/navs.scss:21-65`, `common/foundation/mixins.scss:271-297` |
| `nav-hover` paints a hovered pill's `.d-icon` in `--d-nav-color--active`, not the hover colour | `mixins.scss:290-297` |
| `--d-nav-color--active` is also read by keyboard-shortcut rings, overflow-nav arrows, and (via `--d-nav-border-color--active`) the category/tag drop borders | `keyboard_shortcuts.scss:5,20`, `horizontal-overflow-nav.scss:48`, `select-kit/category-drop.scss:30` |
| Modernize sets `--d-nav-underline-height: var(--space-half)` and a hover underline on body | `upcoming-changes/uc-modernize-foundation-theme/variables.scss`, `nav-pills.scss` |
| `--shadow-header` = `0 0 0 1px var(--content-border-color)`; `--shadow-footer-nav` is a blurred shadow | `color_definitions.scss:153-154` |
| `--footer-nav-height` is 49px on `:root`; `html.footer-nav-visible` pads `#main-outlet` by it | `common/components/footer-nav.scss:5-25` |
| `.wrap` is `max-width: var(--d-max-width)` (1110px) | `common/base/discourse.scss:8,604` |
| Discovery sets body `navigation-topics`, `navigation-category` or `navigation-categories` | `components/discovery/navigation.gjs`, `bodyClass` |
| `.category-heading` shows name and description **only when the category has an uploaded logo**; otherwise the page heading is the sr-only `h1#topic-list-heading` | `components/discovery/navigation.gjs`, `accessible-discovery-heading.gjs:98` |
| `?f=tracked` is sticky on `top_menu` pills: `navigation-item.gjs` copies `currentRouteQueryParams.f` into the href. Only items built by `NavItem.fromText` carry `currentRouteQueryParams` (`models/nav-item.js:99`); `addNavigationBarItem` items don't, so their own href decides. The nav list rebuilds on query-param change (`d-navigation.gjs`, `navItems` depends on `router.currentRoute.queryParams`) | `components/navigation-item.gjs`, `models/nav-item.js`, `lib/topic-list-tracked-filter.js` |
| `f=tracked` is ignored by Hot and Top: `create_list(:hot, …)` sets `options[:filter] ||= :hot` before `default_results`, which merges `@options` (so `f` is present) but then picks `options[:filter] \|\| options[:f]` — `:hot` wins over `"tracked"` (corrected 2026-09-27; checked live on `/hot.json`, `/top.json`). New's subsets call `new_results`/`unread_results`/`new_and_unread_results` without `:filter`, so Tracked applies to all three | `lib/topic_query.rb:336-351,369-381,565-567,810-811,964-981` |
| Signed-out visitors get no empty state: `showEmptyFilterEducationInFooter` returns false without `currentUser`, and `EmptyTopicFilter` reads `currentUser.unified_new_enabled` unguarded. The state sits inside the wrapper outlet `topic-list-bottom` (outletArgs `category`, `tag`, `allLoaded`, `model`), rendered only when `allLoaded`; `api.renderAfterWrapperOutlet` targets `topic-list-bottom__after` (verified against `7b4f0970`, 2026-09-30) | `components/discovery/topics.gjs:127-135,306-345`, `components/empty-topic-filter.gjs`, `lib/plugin-api.gjs:1411` |
| Empty member lists render `EmptyTopicFilter`; its button routes to `discovery.latest`, which keeps sticky `f` | `components/discovery/topics.gjs` (`showEmptyFilterEducationInFooter`), `components/empty-topic-filter.gjs` |
| `api.addNavigationBarItem({ name, displayName, href, customHref, customFilter, forceActive, before })` | `lib/plugin-api.gjs:1617-1685`, `models/nav-item.js` |
| `composer.isOpen` is `this.model?.composeState === Composer.OPEN` — a native read of a classic property core changes with `set`, so a Glimmer getter using it doesn't re-render. Read `get(composer, "model.composeState")` instead (observed live: the bar stayed up) | `services/composer.js:278,839`, `models/composer.js:58,143` |
| Minimized/saving composer: `#reply-control.draft/.saving`, 45px at `bottom: 0`, z `composer content` (400); lifted above a footer nav only under `.ios-device.footer-nav-visible` | `common/base/compose.scss:45-60,143-186,903-915` |
| `navigation-bar-dropdown-mode` value transformer, default `site.mobileView`, decides dropdown vs inline pills; `NavigationBar` is rendered only by `d-navigation.gjs` | `components/navigation-bar.gjs:31-36`, `lib/registry/transformers.js:98` |
| `--d-control-height` is read by modernize's nav-pill height (`uc-modernize-foundation-theme/nav-pills.scss:15`) and `tagging.scss:428` but **defined nowhere** in core's stylesheets at this commit, so that height is dead; pills fall back to `min-height: 30px` (`components/navs.scss`) and only reach the buttons' height where a flex row stretches them | grep of the export |
| `.navigation-container` is flex/wrap with `gap: var(--nav-space)`; `#navigation-bar` has `margin-right: auto`; `.list-controls .container` is flex/wrap only below `sm` | `common/base/list-controls.scss:4-60` |
| Nested topic header: `.nested-view__header` › `TopicStatus`, `h1.nested-view__title > a.fancy-title`, `TopicCategory.topic-category`, outlet `topic-title`. `.nested-view` is `max-width: topic-body-width + 2×padding + avatar` (≈791px), centred; no timeline. No body/html class marks the nested view | `components/nested/header.gjs`, `components/nested.gjs`, `common/nested-view.scss:22-60` |
| Profile tabs all render in `section.user-main`; body classes are per page (`user-summary-page`, `user-activity-page`, `user-preferences-page`, …), none shared | `templates/user*.gjs` |
| Phone empty state: `.empty-state__image { margin-top: 8vh }`, `svg { width: 65vw }` below `sm`; `--empty-topic-filter` adds `padding-top: 7rem` from `sm` | `common/components/empty-states.scss` |
| `dAvatar(user, { imageSize, ignoreTitle, … })` | `ui-kit/helpers/d-avatar.js` |
| `far-bell` is in core's sprite; `table-cells-large` is not | `lib/svg_sprite.rb:142` |
| Font keys `source_sans_pro`, `roboto_slab`, `raleway`, `lora` | `frontend/discourse/admin/lib/constants.js:117-127` |
| Not core variables at this commit: `--on-tertiary`, `--focus-ring`, `--d-transition`, `--line-height-body`, `--header-height`, `--d-nav-pill-color` | grep of the export's stylesheets and `lib/stylesheet` |

## Unified New (verified against `7b4f0970` and live, 2026-09-27)

Announced 2026-06-09 (meta.discourse.org/t/404728). **On for meta.fomio.app**:
`siteSettings.enable_unified_new` is `true` and the member's
`unified_new_enabled` is `true` — auto-promoted, since the change is
`stable` and `promote_upcoming_changes_on_status` defaults to `beta`. Staff
said on 2026-09-09 it will be made Permanent (the opt-out goes).

| Fact | Where |
|---|---|
| Upcoming change `enable_unified_new`, status `stable`, `default: false`, hidden | `config/site_settings.yml:4721-4729` |
| A change at or past the promotion status is on unless an admin stored a value; `permanent` ignores the stored value | `lib/upcoming_changes.rb:255-280`, `promote_upcoming_changes_on_status` default `beta` (`site_settings.yml:667`) |
| `User#unified_new_enabled?` → `upcoming_change_enabled?(:enable_unified_new)`, serialized to the client | `app/models/user.rb:2026`, `current_user_serializer.rb:78` |
| `top_menu` default becomes `latest\|new\|hot\|categories`; `unread` is **not a valid choice** while it's on | `site_settings.yml:305-317`, `lib/top_menu.rb:5-13` |
| `/new` takes `?subset=topics\|replies` (none = All): `new_results`, `unread_results`, `new_and_unread_results` | `lib/topic_query.rb:336-351` |
| Subtabs: core's `NewListHeaderControlsWrapper` → buttons `.topics-replies-toggle.--all/--topics/--replies`, labels `filters.new.*`; rendered by `discovery/topics.gjs` on New for unified members, above the list (with or without topics) | `components/new-list-header-controls-wrapper.gjs`, `components/topic-list/new-list-header-controls.gjs` |
| `subset` is a sticky list query param like `f` | `controllers/discovery/list.js:25,227-230` |
| The New pill's count respects Tracked (`customFilterFn: isTrackedTopic` when `f=tracked`) and adds unread; **the subtab counts don't** (`countNew`/`countUnread` without `customFilterFn`) | `models/nav-item.js:340`, `models/topic-tracking-state.js:720-735`, `components/discovery/topics.gjs` (`newRepliesCount`, `newTopicsCount`) |
| `unread` is dropped from the nav items, but the current filter is re-added, so legacy `/unread` still routes (`discovery.unread`) | `models/nav-item.js:132-139` |
| New is never hidden when empty for unified members | `components/navigation-item.gjs:31-38` |
| Empty New: `topics.none.education.unified_new`; its button can switch subset (`topic.browse_new_replies`/`_topics`) instead of routing to Latest | `components/empty-topic-filter.gjs` |

## Sidebar (verified against `7b4f0970`)

Variables are on `:root` in `common/base/sidebar.scss:3-68`, plus four in
`sidebar-section-link.scss:3-8`. `uc-modernize-foundation-theme/sidebar.scss`
overrides six of them on body.

| Variable | Core value (modernize value, where different) |
|---|---|
| `--d-sidebar-width` | `17em`; `14em` below `lg` |
| `--d-sidebar-row-height` | `2.2em`; `2.4em` below `sm` |
| `--d-sidebar-row-horizontal-padding` | `--space-1` |
| `--d-sidebar-section-link-prefix-margin-right` | `--space-2` — the icon-to-text gap |
| `--d-sidebar-link-color` | `--token-color-text-subtle` |
| `--d-sidebar-link-icon-color` | `--token-color-icon-subtle` (modernize: text-subtle) |
| `--d-sidebar-active-background` | `--token-color-surface-selected` (modernize: surface-hovered) |
| `--d-sidebar-active-color` / `-icon-color` | text-default / icon-default. `-icon-color` **is** read (`sidebar-section-link.scss:273`) |
| `--d-sidebar-active-font-weight` | semibold 600 |
| `--d-sidebar-header-color` / `-icon-color` / `-font-weight` | text-subtle / text-subtle / 600 |
| `--d-sidebar-background`, `--d-sidebar-border-color` | `--token-color-surface` (= `--secondary`), `--token-color-border-default` (= `--primary-low`) |

Link radius is `--token-radius-normal` (4px), a global token.

**Layout.** No rail mode exists. The full sidebar shows from `md` (768px), 14em
below `lg`. Below `md` it's the hamburger drawer
(`components/sidebar/hamburger-dropdown.gjs`). `body.has-sidebar-page` is set
only while the desktop sidebar renders (`components/sidebar.gjs:73`).

**Markup.** Sections are `.sidebar-section-wrapper[data-section-name=…]`
(`components/sidebar/section.gjs:167`); categories is `"categories"`. The
section heading is sized in rem (`sidebar-section.scss:87`), so a font-size
on the wrapper resizes the rows only.

**Outlets.** `before-sidebar-sections` and `after-sidebar-sections` sit
outside the scrolling sections in both the sidebar (`sidebar.gjs:84,98`) and
the drawer (`hamburger-dropdown.gjs:57,79`). Core has no native New topic or
user block in the sidebar.

**Community section.** It's admin-editable (rename, reorder, add URLs), stored
in the database. Admin-added URLs get no counts. `api.addCommunitySectionLink`
links always come after the database links, and they can carry `badgeText`.

**New topic.** `components/create-topic-button.gjs` takes `@canCreateTopic`,
`@action`, `@btnId`, `@btnTypeClass` and `@showDrafts`, and renders
`.topic-create-button__combo`. The list's action is
`composer.openNewTopic({ category })` (`controllers/discovery/list.js:201`).
The list's button lives in `.navigation-controls`.

**Traps:**

- The active-state names are `--d-sidebar-active-*`, **not**
  `--d-sidebar-link-active-*`.
- Set only what differs from core. A no-op looks like configuration.

## Variables — topic list

| Variable | Default | Where |
|---|---|---|
| `--d-topic-list-likes-views-posts-width` | `4.3em` | `common/base/discourse.scss:43` |
| `--d-topic-list-data-font-size` | `var(--font-0)` | same, `:46` |
| `--topic-title-font-weight` | `400` | same, `:67` |
| `--topic-title-font-weight--visited` | `400` | same, `:68` |

## Transformers used

Registered in `frontend/discourse/app/lib/registry/transformers.js`:

| Transformer | Line | Effect |
|---|---|---|
| `bulk-select-in-nav-controls` | `:36` | `true` puts the bulk-select toggle in the nav bar on desktop (`components/d-navigation.gjs:50`) |
| `topic-list-item-mobile-layout` | `:107` | `true` renders the stacked row at any width (`components/topic-list/item.gjs:235`) |
| `topic-list-item-class` | — | adds classes to a row (`item.gjs:243`) |

`apiInitializer(callback)` takes the callback directly. The old version-string
first argument is silently ignored (`frontend/discourse/app/lib/api.js:12`).

## The topic list row

### Two layouts

`components/topic-list/item.gjs` renders either the desktop table row (one
`<td>` per column component in `item/*.gjs`) or the **stacked row**, chosen by
`topic-list-item-mobile-layout`.

Stacked row markup (`item.gjs` ≈ `:323–455`):

```
tr.topic-list-item[.unseen-topic .unread-posts .visited .pinned .closed …]
  td.topic-list-data
    div.pull-left                      avatar (outlet topic-list-item-mobile-avatar)
    div.topic-item-metadata.right
      div.main-link                    TopicStatus, a.raw-topic-link, span.topic-post-badges (unseen), excerpt
      div.pull-right                   PostCountOrBadges → reply count, or unread badges
      div.topic-item-stats.clearfix
        span.topic-item-stats__category-tags   category link, tags
        div.num.activity.last > span.age > a   bumped-at time
```

Useful row state classes: `unseen-topic`, `unread-posts`, `visited`,
`pinned`, `closed`, `archived`, `bookmarked`, `liked`.

### Stacked-row styles are phone-only

Everything for the stacked row in `common/base/_topic-list.scss` sits inside
`@include viewport.until(sm)` (**lines 730–964**). The file loads everywhere,
but the rules only apply below 640px. So on desktop the stacked row is
**unstyled by core**; on phones core's phone rules apply. Among them:

- `.right { margin-left: 55px }` — room for the avatar
- `.topic-list-data { max-width: 300px }`
- `.main-link { font-size: var(--font-up-1) }`
- `.topic-item-stats .num.activity { margin-left: auto }`
- category and tag badges get `pointer-events: none` ("targets too small")
- `.num.posts-map { font-size: var(--font-up-2) }`

### Desktop cell rules that leak into the stacked row

These apply at every width under `.topic-list` (`common/base/_topic-list.scss`):

- `.num { text-align: center; font-size: var(--d-topic-list-data-font-size) }` (`:314`)
- `.badge-posts { font-weight: 700 }` (`:322`) — no variable
- `.num.activity a { padding: 15px 5px }` (`:330`)
- `.posts { width: var(--d-topic-list-likes-views-posts-width) }` (`:608`)
- `a.title` weight from `--topic-title-font-weight` (`:88`, `:116`)

### The reply count element

`components/topic-list/item/replies-cell.gjs` renders
`div.num.posts-map.posts.{heat}.topic-list-data > a.badge-posts`. It carries
**`topic-list-data`** and **`posts`**, so any rule aimed at the row's cell or
at the posts column hits it too.

### Header and bulk select

The `<thead class="topic-list-header">` always renders desktop columns
(`components/topic-list/list.gjs:202`). The bulk-select toggle lives in it
(`header/bulk-select-cell.gjs`), unless `bulk-select-in-nav-controls` is on.
While bulk select is active the table gets `.bulk-select-enabled`.

## The topic page (verified against `7b4f0970`)

Full-tree export of the server's commit, so every path and line here is the
version the site actually runs.

### Variables

| Variable | Default | Where |
|---|---|---|
| `--d-post-control-border-radius` | `var(--d-button-border-radius)` | `common/base/topic-post.scss:362` (on `:root`) |
| `--d-post-control-text-color` / `-icon-color` | `--primary-low-mid` | same, `:363,365` |
| `--d-post-control-text-color--hover` / `-icon-color--hover` | `--primary` | same, `:364,366` |
| `--d-post-control-background--hover` | `--primary-low` | same, `:367` |
| `--d-post-control-create-text-color` / `-icon-color` | `--primary-high` | same, `:368,369` |
| `--d-post-control-sibling-text-color--hover` | `--primary-medium` | same, `:370` |
| `--topic-body-width` | `690px` | `common/foundation/base.scss:5` (`variables.scss:17`) |
| `--topic-body-width-padding` | `var(--space-3)` (`$`=11px) | same, `:6` |
| `--topic-avatar-width` | `45px` | same, `:7` |
| `--topic-timeline-border-color` | `$tertiary-low-or-tertiary-high` | `color_definitions.scss:159` |
| `--topic-timeline-handle-color` | `light-dark(…)` | same, `:160` |
| `--onebox-shadow-color` | `--primary-100` | `common/base/onebox.scss:4` |
| `--onebox-border-color` | `--primary-300` | same, `:5` |

Core has **no** variable for: the post body's font face or size, the onebox
surface colour, or row rhythm in the post stream.

### The timeline breakpoint is JavaScript, not CSS

`MIN_WIDTH_TIMELINE = 925` in
`frontend/discourse/app/components/topic-navigation.gjs:16`. `_performCheckSize`
(`:48`) sets `renderTimeline` from a `matchMedia("(min-width: 925px)")` and
sets `withTopicProgress` to its inverse whenever the topic has more than one
post — so below 925px core swaps the timeline for the progress bar on its own.
It also drops the timeline on `site.mobileView` and when vertical space is
short with the composer preview open. **There is no setting and no variable**;
moving the breakpoint means overriding JS. W4 originally wanted 1280px and was
amended to core's 925px on 2026-09-20.

### Which post buttons show is a site setting

| Setting | Default | Where |
|---|---|---|
| `post_menu` | `read\|like\|copyLink\|flag\|edit\|bookmark\|delete\|admin\|reply` | `config/site_settings.yml:292` |
| `post_menu_hidden_items` | `flag\|bookmark\|edit\|delete\|admin` | same, `:311` |

`post_menu` is the order of the whole row; `post_menu_hidden_items` is the
subset collapsed behind the **More** toggle. The wireframe's "Like and Reply
persistent, the rest under More" is therefore native configuration, not theme
code — an admin action, like `top_menu`.

### Suggested topics is already the theme's own row

Core renders the bottom-of-topic area as `.more-topics__container`
(`common/components/more-topics.scss`), a tabbed region whose components are
`frontend/discourse/app/components/more-topics.gjs` and `suggested-topics.gjs`.
Each tab's body is an ordinary `.topic-list`, so the
`topic-list-item-mobile-layout` transformer in `fomio-topic-list.js` — which
returns `true` for every list — **already** renders suggested topics as the
Fomio feed row. Nothing extra is needed for the wireframe's "More in
Technology" block.

One catch: `.more-topics__list-title` is `display: none` unless the container
has `.single-list`. With more than one tab core shows nav pills instead of the
wireframe's text heading.

### Onebox markup

`lib/onebox/templates/_layout.mustache` is the frame for every provider:

```html
<aside class="onebox {{subname}}" data-onebox-src="{{link}}">
  <header class="source"><img class="site-icon"><a href>domain</a></header>
  <article class="onebox-body"> …provider view… </article>
  <div class="onebox-metadata"></div>
</aside>
```

The generic article view (`allowlistedgeneric.mustache`) is
`img.thumbnail` → `h3 > a` → `p`. Core styles it as a floated thumbnail:
`.onebox-body img:not(.avatar, .onebox-avatar-inline, .emoji)` gets
`float: left; max-width: 20%; max-height: 170px`
(`common/base/onebox.scss:175`). The card's frame comes from the
`onebox-shadow($thickness)` mixin (`:8`), which paints a 1px ring in
`--onebox-border-color`, an outer ring in `--onebox-shadow-color`, and sets
`border-radius: calc(var(--d-border-radius) - ($thickness / 2))` — so the
onebox corner already follows `corner_style`.

Per-provider classes exist on the same `aside` (`.onebox.githubrepo`,
`.githubpullrequest`, `.githubissue`, `.githubblob`, `.githubactions`, …), so a
provider-specific card is a class away, with no routing code.

## Core plugins relevant to Fomio

Bundled in core under `plugins/` (confirmed in the core repo):

- **discourse-post-voting.** Site setting `post_voting_enabled` (default
  false). Enabled per category through the custom fields
  `create_as_post_voting_default` and `only_post_voting_in_this_category`.
  Votes (`PostVotingVote`) have direction `up` or `down`. Only posts without
  `reply_to_post_number` are votable, and you can't vote on your own post.
  `PostVotingComment` is one flat comment layer under each answer, upvote-only.
  Other settings: `post_voting_comment_enabled`,
  `post_voting_comment_limit_per_post` (10),
  `post_voting_comment_max_raw_length` (600),
  `post_voting_enable_likes_on_answers`,
  `post_voting_undo_vote_action_window` (10).
- **discourse-topic-voting.** Topic-level votes. It's on for meta.fomio.app
  (`/votes` exists).
- **discourse-reactions.** `discourse_reactions_enabled` (default true), with
  a configurable reaction list.
- **discourse-gamification.** Points and a leaderboard — the karma
  candidate. `discourse_gamification_enabled` (default false).
- **chat**, **discourse-solved**, **discourse-ai** and others.

Theme components by Discourse, not bundled: `discourse-topic-cards` (dropped
for now) and `discourse-topic-thumbnails`.

## Live site facts (meta.fomio.app, 2026-09-18/19)

- 12 top-level categories, 15 subcategories. Most content is in Interesting Finds.
- Tags, chat and badges are **off** (`/tags` and `/badges` return 404).
- Topic voting is on.
- Current `top_menu` tabs are Latest, New, Hot, Categories. D1 wants Latest,
  Hot and Top for everyone, plus New and Unread signed in. *(Superseded
  2026-09-27: Unified New is on, so Unread is New › Replies and `unread`
  can't be added to `top_menu` — see Unified New above.)*
- Fonts render as a sans heading and serif body — **reversed from T6**. Check
  Admin → Fonts.
- Core's welcome banner (with a search box) shows above the list.
