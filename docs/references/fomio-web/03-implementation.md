# 03 — Implementation

State on 2026-09-26: the mobile bottom bar (2A), aligned with the design
pack, plus the first shared-shell variables (shape, nav pills, list-page
column). Each element's core source is in [08](08-mockup-core-map.md).

## Files

**Composer implementation update, 2026-09-30:** the first local v4 slice is
recorded in [20 — implementation start](20-composer-v4-implementation-start.md).
`fomio-composer-feedback.gjs` adds read-only draft feedback in the allowlisted
`before-composer-fields` outlet (both core layouts pass the native `model`).
`fomio-composer-category-search.js` extends the native filter's `didRender`
through `api.modifyClass` to name only the composer's category search input.
These add no editor, save/close action or request. The outlet fills core's
missing mobile text and the user-requested offline warning; configuration
cannot add either. Two scoped translations and corresponding styles are
included. Native integration tests now pass; see [21](21-composer-v4-native-implementation-and-qa.md) for evidence, the responsive shell, and outstanding release gates. This is not deployed.

| File | Holds |
|---|---|
| `about.json` | Theme metadata and the Fomio / Fomio AMOLED palettes (defaults, editable in Admin → Colours) |
| `common/common.scss` | Shell variables (shape, nav pills, list-page column), the bottom bar's styles, topic-card fixes (3A), and the native composer presentation (21) |
| `javascripts/discourse/api-initializers/fomio-bottom-bar.gjs` | The mobile bottom bar (2A) |
| `javascripts/discourse/api-initializers/fomio-category-context.gjs` | Visible category/subcategory identity where core has no logo-led heading (2B) — core's own `.category-heading__content` markup, no heading element |
| `javascripts/discourse/api-initializers/fomio-mobile-tabs.js` | Core's list tabs inline on phones instead of the dropdown (2E), via the `navigation-bar-dropdown-mode` transformer; keeps the active tab scrolled into view |
| `javascripts/discourse/api-initializers/fomio-tracked-filter.js` | Tracked on/off filter in the nav row (2C), via core's `api.addNavigationBarItem` |
| `test/acceptance/fomio-tracked-filter-test.js` | QUnit acceptance tests for the Tracked filter, its empty state, and Unified New subsets (desktop and mobile). Needs a development Discourse: `/theme-qunit` refuses to run on meta.fomio.app (04) |
| `javascripts/discourse/api-initializers/fomio-visitor-empty-list.gjs` | Core's empty-list state for signed-out visitors (4.5), with ways out to Latest, Categories and Hot |
| `test/acceptance/fomio-visitor-empty-list-test.js` | QUnit acceptance tests for the visitor empty state. Needs a development Discourse (04) |
| `javascripts/discourse/api-initializers/fomio-composer.js` | Native Format grouping via `onToolbarCreate`; replaces the historical opt-in preview; see 21 |
| `javascripts/discourse/lib/fomio-composer-format.js` | Groups original native commands under Format without replacing the editor |
| `javascripts/discourse/api-initializers/fomio-composer-audience.gjs` | Native category audience through an allowlisted outlet; see 21 |
| `test/native-composer-format.test.mjs` | Adapter tests against the pinned native Toolbar |
| `locales/en.yml` | Theme description and the theme-owned Format trigger label |
| `scripts/check-*.sh` | The four guards (04) |

No `settings.yml`. Six initializers (one opt-in experiment), three allowlisted outlets, one nav item and one value transformer, below. One theme component is attached (below).

## Theme components attached

Components are separate themes on the server, not files in this repo, so
`check-duplication.sh` doesn't see them. Each is a decision; record it here.

| Component | Server | Phase | Detail |
|---|---|---|---|
| **Topic Cards** — [`discourse/discourse-topic-cards`](https://github.com/discourse/discourse-topic-cards), official | Theme **37**, installed from git 2026-09-27 at `6e74da3` (main); child of theme **36 only**. Theme 36 was the site default for part of 2026-09-27 (the user's change, used for the 3A signed-out check); the site default switched between 31 and 36 more than once that day (36 again at the 3B check), so check `/admin/themes.json` before assuming 36 and 37 are live. Theme 31 has no components | 3A | The user's decision (2026-09-27), replacing a custom card. **Scope:** lightweight discovery previews — thumbnail, title, excerpt, author, likes, replies, age; no Save/bookmark or share on cards (those are 3D, on the topic screen), so none of the component's settings or theme code adds them. **Accepted exceptions (2026-09-27):** the like toggle is the one card action; cards stay on every native list (Home, category, subcategory, suggested) on purpose; theme 37 stays the upstream component, attached to theme 36 only, until a Fomio-owned fork replaces it (not planned yet). It is Discourse's own card implementation: core has no card component or API at `7b4f0970` (the only other card is inside the bundled Horizon theme and loads only when Horizon is the active theme, `app/models/theme_field.rb:149`). Its main branch covers the server: `.discourse-compatibility` pins only versions below 2026.2, and every old import path it uses (`discourse/helpers/d-icon`, `number`, `concat-class`, `format-date`, `avatar`, `category-link`, `discourse-tags`, `dir-span`, `discourse/components/user-link`) is mapped by core's `ui-kit-shims.js`. **How it works:** `topic-list-class`, `topic-list-item-class`, `topic-list-item-mobile-layout` (false), `topic-list-columns` (adds a thumbnail cell, and on phones a category/tags cell) and a `topic-list-item-click` behaviour transformer; it renders author, excerpt and a stats row into the core outlet `topic-list-main-link-bottom`, and a comment icon via the `topic-list-before-reply-count` connector. Its `about.json` turns on the `serialize_topic_excerpts` and `serialize_topic_op_likes_data` modifiers and thumbnail sizes, so this theme sets none. **Settings (theme 37):** `show_likes` true, `show_reply_count` true, `show_activity` true, `show_views` false (the pack's no view-count rule), `show_publish_date` **false** (its label is the component's own "Published" string; user's choice 2026-09-27), `set_card_max_height` true / 275, `show_on_categories` empty (cards on every list), `show_for_suggested_topics` true. **String exception:** the like button's tooltip and error dialogs are component strings (`like_toggle.*`), editable in the component's translations in admin; accepted by the user 2026-09-27. **Fix in this theme:** `.topic-card__excerpt-text { overflow-wrap: anywhere }` — on phones the component's `.main-link` grid grew to an unbroken URL in an excerpt and pushed the page 8px sideways at 375px. `.topic-card.selected .topic-card__stats td:first-of-type { box-shadow: none }` — core's keyboard marker `.topic-list-item.selected td:first-of-type` (`components/keyboard_shortcuts.scss:2`) also matched the first cell of the component's nested stats table, drawing a stray bar beside the like button when a title had focus. Upgrades: update theme 37 from git in admin; re-check the shims and this fix against the server's commit first |

## Adding code

Each addition should be able to answer, in its commit or here:

1. **Which launch-journey step** it serves (the redesign rule, 00).
2. **Why a setting can't do it** — the priority ladder, 00.
3. **Which core names it relies on**, verified in the export (02).

New outlets and theme settings are decisions: record each below when it is
added.

## Outlets in use

| Outlet | Piece | Why this one |
|---|---|---|
| `below-footer` | Mobile bottom bar | Rendered on every route, outside `#main-outlet-wrapper` (`templates/application.gjs`). The bar is `position: fixed`, so its DOM place only matters for stacking. Core's own `footer-nav` wrapper outlet only renders in DiscourseHub and iOS PWAs (`controllers/application.js`, `showFooterNav`), so it can't carry the bar |
| `category-heading` | Category/subcategory context | Core passes the native category model here, but only renders a visible category name and description when an uploaded logo exists (`components/discovery/navigation.gjs`). The outlet fills that gap without replacing core's accessible `h1`, navigation, or actions; the component outputs nothing when the native logo-led heading is present |
| `topic-list-bottom` (`__after`, via `api.renderAfterWrapperOutlet`) | Visitor empty list (4.5) | Core renders its empty-list state (`EmptyTopicFilter` → `DEmptyState`) only for a signed-in member (`components/discovery/topics.gjs`, `showEmptyFilterEducationInFooter`), so a visitor on a list with nothing they can see gets no content at all. `topic-list-bottom` is the wrapper around that state and renders only when the list is fully loaded; `__after` adds to core's content without replacing it, and gets the list `model`. The piece renders core's own `DEmptyState` with core's `empty-topic-filter` identifier, SVG and generic text (`topics.none.education.generic`), only when there is no current user and no topics. The CTA and tip links are Discourse's existing lists — Latest (`topic.browse_latest_topics`), Categories (`filters.categories.title`), Hot (`filters.hot.title`) — minus the site-wide list already showing (and minus Hot from an empty site-wide Latest). No recommendations, counts or signup prompt. One CSS rule spaces the tip links |

## Nav items added

| Item | API | Detail |
|---|---|---|
| Tracked filter | `api.addNavigationBarItem` (`lib/plugin-api.gjs:1642`) | Name `fomio-tracked`, label core `user.tracked_categories`, `before: "categories"`. Signed in only, not on the categories page. `customHref` toggles `f=tracked` on the current URL; `init` adds `--on` while it's on. **Off is a click handler** (fixed 2026-09-26): following the plain off href left a signed-in preview on `?f=tracked`, so a capture-phase listener on `li.fomio-tracked.--on > a` calls `preventDefault()` and `router.transitionTo({ queryParams: { f: null, filter: null } })`. Core's interceptor then skips the link (`lib/intercept-click.js`, `wantsNewWindow`); modified clicks keep the href. **Empty state (2D, 2026-09-26):** with the filter on and nothing tracked, core's `EmptyTopicFilter` button (`topic.browse_latest_topics`, route `discovery.latest`) kept the sticky `f` and reloaded the same empty list. The same listener catches that button while the filter is on — matched by core's label through `i18n`, not a literal — and transitions to `discovery.latest` with `f`/`filter` cleared; `stopPropagation()` keeps core's own handler from running. Core's other empty-state buttons (the New list's subset switch) are untouched. Not an outlet, so check-duplication has nothing to allowlist |

## Transformers used

| Transformer | Value | Why |
|---|---|---|
| `navigation-bar-dropdown-mode` (`lib/registry/transformers.js:98`, read in `components/navigation-bar.gjs`) | `false` | 2E, decided with the user 2026-09-26. Core's default is `site.mobileView`: below `sm` the list's pills fold into a menu whose trigger names only the current tab. Returning `false` keeps core's own `NavigationItem`s inline — no markup. Only `d-navigation.gjs` renders `NavigationBar` (discovery and tag lists). The same initializer scrolls the tab row, never the page, to the active tab after each `routeDidChange`; with today's `top_menu` core's re-render already starts every active tab in view, so this only matters if an admin lengthens `top_menu` |

## Core overrides

| What | How | Why a setting or API can't |
|---|---|---|
| Hamburger hidden on mobile while the bar shows | Core's `hideApplicationHeaderButtons "menu"` helper (`helpers/hide-application-header-buttons.js` → `services/header.js`) | It *is* the API. Undone when the bar hides (admin, auth, composer) |
| Header avatar hidden on mobile while the bar shows | CSS: `.fomio-bottom-bar-visible .d-header-icons .header-dropdown-toggle.current-user` (`components/header/user-dropdown.gjs`) | The header hider accepts only search, login, signup and menu |
| Bar height 56px | `--footer-nav-height` on `html.fomio-bottom-bar-visible` (core's var, `footer-nav.scss:8`) | Core's footer-nav padding and offsets read it, so they grow with the bar |
| Minimized/saving composer lifted above the bar | CSS: `html.fomio-bottom-bar-visible #reply-control:is(.draft, .saving) { bottom: --footer-nav-height + safe area }` | The 45px draft strip sits at `bottom: 0` (`base/compose.scss`), under the bar (z 900 over 400), so a minimized post vanished on phones. Core lifts it only on iOS, for its own footer nav (`.ios-device.footer-nav-visible #reply-control`); the bar shows on every phone |
| Phone tab row | CSS below `sm`: `.navigation-container #navigation-bar { flex: 1 0 100%; flex-wrap: nowrap; margin-right: 0; overflow-x: auto; scrollbar-width: none }`, `> li { flex: none }` | Inline pills otherwise wrap into two or three rows beside the actions. DOM order (breadcrumbs, tabs, actions) is kept, so focus order matches the visual order |
| Actions flush right | `.navigation-container .navigation-controls { margin-left: auto }`, every width | Core's wrapped actions row starts at the left; with this the same row ends at the column edge on phones, tablets and a desktop category page. On a single desktop row it's a no-op (both auto margins share one gap) |
| Topic and profile on the list column | `body:has(#topic.nested-view), body:has(section.user-main) { --d-max-width: 840px }` | Core sets no body class for the nested topic view or the profile; `:has()` keys off core's own containers. Only `--d-max-width` changes, so title, category, identity and actions stay core's (2B, 2026-09-27) |
| Phone empty-state picture capped | `html.fomio-bottom-bar-visible .empty-state__container.--empty-topic-filter .empty-state__image` below `sm`: `margin-top: var(--space-4)`, `svg { width: min(65vw, 10rem) }` | Core's `8vh` / `65vw` sizing put the button under the bar on short screens (2D, 2026-09-27) |
| Categories page Latest rail compacted (3B) | `.categories-and-latest .latest-topic-list-item`: `padding: --space-2 --space-1`, `gap: --space-3`, `align-items: flex-start`; avatar `--space-6`; `.main-link` `flex: 1 1 auto; max-width: none`; `.top-row` 2-line `-webkit-line-clamp` at `--font-0`; `a.title` `padding: 0`; `.posts-map` `--font-0` | Core's rail rows (base/categories-topic-list.scss) were 81–183px in the 393px column; the concept is a compact rail. No markup change; full titles stay in the links |
| Core's footer-nav layout reused | `htmlClass "footer-nav-visible"` — core pads `#main-outlet` and lifts the topic progress bar, nested-view actions and the iOS composer by `--footer-nav-height` (`common/components/footer-nav.scss`, `nested-view.scss`, `compose.scss`) | Borrowing core's class keeps every core offset right without restating them |
| Subcategory list as one row of links (3B) | CSS on `body.navigation-category #header-list-area`: `.category-list` flex/wrap; each subcategory (`table.category-list > tbody > tr` on desktop, `.category-list-item` on phones) a chip with an inset `--content-border-color` ring; `display: contents` on the phone row's inner table parts; description, topic count, `.category-topics-count` and nested subcategories hidden; `thead` visually hidden (it labels the tbody) | Core renders the list in full rows (`categories-only.gjs` → `parent-category-row.gjs`) and no `subcategory_list_style` is compact: at 375px General's six rows took 1,248px. The setting turns the list on; the layout has no setting |
| Subcategory row: member badges and the topics head (3B follow-up, 2026-09-27) | `td.topics > div:not(.unread-new)` hidden (core's unclassed stat div), so `CategoryUnread`'s `.unread-new` / `.category__badges` badges stay; `.category__badges .badge-notification` gets `--space-2` before it; `table.category-list > thead th.topics { display: none }` | Core puts the raw count and the member's new/unread badges in the same cell (`parent-category-row.gjs:210-219`). Hiding the whole cell removed the badges too; hiding only the head of a column that has no visible data stops screen readers announcing it |
| Docked composer aligned with the column (3E) | `@include viewport.from(sm)`: `body:not(.has-sidebar-page) #reply-control:not(.fullscreen).hide-preview { margin-left: max(0.67em, calc((100% - var(--d-max-width)) / 2 + 0.67em)) }` — core's own selector and formula (`common/base/compose.scss`) | Core applies the formula only from 1110px, assuming its 1110px column; with the theme's 840px column the composer sat at the window's edge between ~790 and 1110px. No setting |
| Bottom bar New Topic starts in the page's category (3E) | `fomio-bottom-bar.gjs` `newTopicCategory`: `router.currentRoute.attributes.category`, then core's `createTopicTargetCategory` rule (`canCreateTopic`, else `subcategoryWithCreateTopicPermission` when `default_subcategory_on_read_only_category`), passed to `composer.openNewTopic({ category })` | Core's list New Topic button passes the category; the bar called `openNewTopic()` bare, so a category page opened the composer in the default category |

## Planned

| Piece | Phase | Detail |
|---|---|---|
| Mobile bottom bar | 2A | **Built 2026-09-26**, `api-initializers/fomio-bottom-bar.gjs`. Below `sm` (`site.mobileView`): Home (`/latest`) · Categories (`/categories`) · New Topic (`composer.openNewTopic()`, if `can_create_topic`) · Notifications (opens core's user menu via `header:keyboard-trigger`; badge = `all_unread_notifications_count`) · Profile (`/u/:username`). Active states: Home on every site-wide list (`discovery.*` without a category — `/`, `/latest`, `/hot`, `/new`, `/unread`, `/top`, since those are Home's own tabs), with `aria-current="page"` only on `discovery.latest`; Categories on `discovery.categories` and every category-scoped list, with `aria-current="page"` only on `discovery.categories` (the page it links to; fixed 2026-09-26, it was on every category list); Notifications while the user menu is open; Profile on the member's own `/u/` pages. Signed out: Home and Categories only; the header keeps Log in / Sign up. Labels are core strings (`home`, `filters.categories.title`, `topic.create`, `user.notifications`, `user.profile`), so "Discover", "Create" and "Me" became Categories, New Topic and Profile. While the 69 old site-text overrides remain (05, 1.1), New Topic reads "New Byte". Hidden on admin, auth routes and while the composer is open. Known gap: in an iOS PWA core's own footer nav also shows. **Aligned with the pack 2026-09-26:** 56px, header hairline instead of shadow, bold labels, active item `--tertiary`, Profile shows the member's avatar (ringed when active), bell regular/solid by menu state, badge `--tertiary`. **2A fixes 2026-09-26** (found in the signed-in preview at 375px): every icon slot is the avatar's height (`--space-6`), so Profile's label no longer sits 4px lower; labels share core's `--line-height-medium`, because buttons don't inherit line-height; items keep flexbox's automatic minimum width (no `min-width: 0`), so "Notifications" isn't cut off — at 320px its column widens to 75px and the others stay 61–62px; the composer check reads `get(composer, "model.composeState")`, because `composer.isOpen` reads a classic property natively and never re-rendered the bar, which stayed up (with `footer-nav-visible`) under the open composer. |

## Shell variables (Phase 2)

All core variables, verified against `7b4f0970`. Source per element: 08.

| Variable | Set on | Value | Why |
|---|---|---|---|
| `--d-border-radius` | `:root, body` | 8px | Pack's shape; buttons, inputs, pills follow it |
| `--d-border-radius-large` | `:root, body` | 12px | Core's default is twice the radius (16px) |
| `--d-nav-color--active`, `--d-nav-bg-color--active` | `.nav-pills` | `--secondary` on `--quaternary` | Filled active pill (2C). Scoped: core reuses the active colour for rings and borders elsewhere |
| `--d-nav-color--hover`, `--d-nav-bg-color--hover` | `.nav-pills` | `--primary` on `--d-hover` | Hover wash |
| `--d-nav-underline-height` | `.nav-pills` | 0 | The fill replaces modernize's underline |
| `--d-max-width` | `body.navigation-topics`, `.navigation-category`, `.navigation-categories` | 840px | One reading column on list pages (2D); not on topics (timeline, 3D) |

One selector override: a hovered, inactive pill's icon, because core's
`nav-hover` mixin paints it in the active colour.

## Theme settings

None.

## Reusable from `archive/v0`

Verified work that may be worth lifting when its phase comes — re-check each
against core first. `git show archive/v0:<path>` to read it.

| Piece | Where on `archive/v0` | Useful for |
|---|---|---|
| `corner_style` → `--d-border-radius` mapping | `common/common.scss`, `settings.yml` | Phase 2, if a shape setting is still wanted |
| Onebox card treatment, scoped to the topic | `common/common.scss` (Onebox) | 3D |
| Nav-tab restyle on core's `.nav-pills` | `common/common.scss` (Nav tabs) | 2C |
| Stacked topic-list row via transformer | `javascripts/.../fomio-topic-list.js` | Superseded for 3A by the topic-cards component (2026-09-27) |
| Mistakes-made list | `docs/03-implementation.md`, last section | Everything |

Composer audience: `fomio-composer-audience.gjs` uses the verified
`after-composer-category-input` outlet and its native `composer` argument.
It reads `category.read_restricted`, supplied by `BasicCategorySerializer`,
and renders core’s `category.visibility.public` / `group_restricted` copy.
Unknown category access is omitted; this is presentation, never authorization.
The outlet is allowlisted, and no new request or chooser is introduced.
