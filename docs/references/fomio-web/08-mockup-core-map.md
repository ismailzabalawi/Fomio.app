# 08 — Mockup to core map

Phase 0, step 3 of [07](07-production-implementation-plan.md): for each
element of the Claude Design screen pack, where it comes from in Discourse.
Verified against the server's core, `7b4f0970` (confirmed from the live
`generator` meta tag on 2026-09-26). Paths are relative to
`frontend/discourse/app/` or `app/assets/stylesheets/` in that export.

The pack is claude.ai/design project `10e05e50-973c-4ddb-836f-406e5456a4f2`
(`mockups/00 Index.dc.html`, rules in `mockups/README.md`). It is a visual
reference: an element ships only once it has a source in this table.

**Source key:** *Setting* (admin), *Native* (core renders it as is),
*Variable* (core CSS variable the theme sets), *Theme* (theme CSS on core
markup), *Built* (theme markup in an allowlisted place), *Open* (needs a
decision), *Drop* (no core source; leave out).

## Foundations

| Element | Source | Detail |
|---|---|---|
| Palette: ink on white, one violet; AMOLED black dark | Setting | `about.json` → "Fomio", "Fomio AMOLED". Adopted 2026-09-26. Pick them per theme in Admin → Colours / theme settings |
| `--on-tertiary` (pack's text-on-violet) | Drop | Not a scheme slot or core variable. Core puts `--secondary` on tertiary fills |
| Fonts: Source Sans for UI/body, Roboto Slab for titles | Setting | `base_font` = `source_sans_pro`, `heading_font` = `roboto_slab` (`admin/lib/constants.js:117,122`). Adopted 2026-09-26; **not yet set on the site** |
| Monospace JetBrains Mono | Native | Core already emits `--d-font-family--monospace` as JetBrains Mono (`lib/stylesheet/importer.rb:71`) |
| 8px radius, 12px large | Variable | `--d-border-radius`, `--d-border-radius-large` (`foundation/base.scss:8-9`). Buttons, inputs, pills follow |
| Pill-shaped tags | Drop for now | `--d-tag-border-radius` exists, but tags are off |
| Card, dropdown, modal shadows; none on AMOLED | Native | Core's `--shadow-*` are compiled per scheme (`color_definitions.scss:148-154`). Not re-tuned |
| Focus ring `--focus-ring` | Drop | Not a core variable. Core's own focus styles stay |
| `--d-transition`, `--line-height-body`, `--header-height` | Drop | Not core variables at this commit |

## Global header (FmHeader)

| Element | Source | Detail |
|---|---|---|
| Hairline under the header | Native | Core's `--shadow-header` is already a 1px `--content-border-color` ring (`color_definitions.scss:153`) |
| Logo / site title | Setting | `logo`, `title`. The pack shows the title until a logo is uploaded |
| Desktop search **field** in the header | Setting, **Open** | `search_experience` = `search_field`. Docs 05 proposed `search_icon`. The user decides |
| Notifications bell + avatar; Sign Up + Log In | Native | Core header icons and auth buttons |
| Mobile: logo + search only | Built | Hamburger hidden and avatar hidden while the bottom bar shows (03) |
| Signed-out mobile Log In in the header | Native | Core keeps its login button in the mobile header; the bar has no auth item (pack's Unresolved 2) |
| Content aligned to the 840px column | Variable | `--d-max-width` on list pages only, so the header `.wrap` aligns there. Topic pages keep core's width (below) |

## Mobile bottom bar (FmBottomNav)

| Element | Source | Detail |
|---|---|---|
| Five items, signed-out two | Built | `below-footer`, `fomio-bottom-bar.gjs`; labels core i18n (03) |
| 56px + safe area | Variable | `--footer-nav-height` on `html.fomio-bottom-bar-visible`; core's footer-nav layout reads it |
| Active item violet | Theme | `.active` → `--tertiary` |
| Profile avatar with ring | Built | `ui-kit/helpers/d-avatar.js`, `imageSize="small"` |
| Bell regular / solid when open | Built | `far-bell` / `bell`, both in core's sprite (`lib/svg_sprite.rb:142`) |
| Categories grid icon (`table-cells-large`) | Drop | Not in core's sprite; the bar keeps `list`. Adding it needs the `svg_icons` modifier; not worth it |
| Top hairline, no shadow | Variable | `--shadow-header` reused as the bar's `box-shadow` |
| Icons and labels on one line; equal columns | Theme | Icon slots the avatar's height (`--space-6`), labels `--line-height-medium`; a column widens only if its core label needs it (03) |
| Minimized composer above the bar | Theme | Core's iOS footer-nav lift, applied wherever the bar shows (03) |

## Context header (FmCategoryHeader) — 2B / 3B

| Element | Source | Detail |
|---|---|---|
| Category name and description | Built | `category-heading` outlet passes the core category model. Without an uploaded logo (core's own condition, `uploaded_logo.url`), `fomio-category-context.gjs` renders core's logo-heading markup minus the logo: `.category-heading__content` > `d-category-badge` + `p.category-heading__description` (description only when present). With a logo it renders nothing and core's heading shows. Not a heading element, so the sr-only `h1` (`accessible-discovery-heading.gjs:98`) stays the only one. A subcategory's badge carries `--has-parent` (split square), as in core; the breadcrumb names the parent |
| Breadcrumb Categories › Parent | Native (3C, decided 2026-09-27) | Core's category-drop breadcrumbs in `.category-breadcrumb`. No theme-made parent link: the parent is reached through the second dropdown ("remove filter", site text), keyboard-operable |
| "Also in …:" sibling links on a subcategory | **Drop** (3C, decided 2026-09-27) | Core has no sibling list or "Also in" string; the second breadcrumb dropdown already lists the siblings |
| Notification level button | Native, kept in the nav row (decided 2026-09-27) | Core's category notifications button in `.navigation-controls` (`d-navigation.gjs:428-440`). The pack puts it in the header; core has no setting, transformer or outlet for that, and a moved copy would duplicate core's control and vanish on logo categories |
| New Topic button | Native | `create-topic-button.gjs`, label `topic.create` |
| "24 topics / week" | **Deferred** (2026-09-27) | Core has the wording (`categories.topic_stat`), but category pages carry no `topics_week` (only `/categories.json` does) and `topic_count` excludes subcategories. Q4 already drops watcher counts |
| Subcategory links | Setting, Theme | Core's subcategory list (`show_subcategory_list` on, `subcategory_list_style` = `rows`, on the three parents; 3B, 2026-09-27), restyled by theme 36 as one wrapping row of core's category links, without descriptions or counts. A subcategory's siblings stay in core's breadcrumb dropdown |

## Local navigation (NavPills) — 2C

| Element | Source | Detail |
|---|---|---|
| Hot · Latest · New · Categories | Setting | `top_menu`. No Unread tab: Unified New is on (02), so unread topics are New › Replies and `unread` isn't a valid `top_menu` choice |
| New › All · Topics · Replies | Native | Core's Unified New subtabs (`new-list-header-controls-wrapper.gjs`, `?subset=`). Not restyled. Tracked keeps `subset`; server filters all three. Their counts ignore Tracked (core) |
| Filled active pill, hover wash | Variable | `--d-nav-*` scoped to `.nav-pills` (`components/navs.scss`, `foundation/mixins.scss` `nav-active`) |
| Mobile: horizontal tab row, not core's dropdown | Built | **Changed 2026-09-26 (2E, user's decision)** — the roadmap's "compact, horizontal tabs". Core's `navigation-bar-dropdown-mode` value transformer returns `false` (`fomio-mobile-tabs.js`), so core's own pills render inline below `sm`; theme CSS gives them their own row that scrolls sideways. The dropdown's trigger showed only the current tab, hiding Tracked's on-state. Pills stay core's 30px `min-height` on that row (compact; on desktop the row stretches them to the buttons' 38.5px) |
| Actions flush right at every width | Theme | `.navigation-controls { margin-left: auto }`; core leaves a wrapped actions row on the left (tablet, a desktop category page, phones) |
| Tracked on/off filter | Built | `fomio-tracked-filter.js`, core's `api.addNavigationBarItem` (no outlet, no markup). Label core's `user.tracked_categories`. Signed in only; hidden on the categories page; placed before Categories. Its href toggles `f=tracked` on the current list, keeping other params. Core's `top_menu` pills keep `f` while it's on (`navigation-item.gjs`); extra items aren't given the route's query params (`nav-item.js:99`, only `fromText`), so its href can point off; clicks turn it off through an explicit query-param reset (`router.transitionTo({ queryParams: { f: null } })`), because the plain href didn't clear it for a signed-in member in the preview. On-state is `li.fomio-tracked.--on` (selected wash, violet text), not `forceActive`, which would clear the current tab's active state. Core hides its own Categories pill while the filter is on (`skipCategoriesNavItem`) |
| Default scope unlabeled | Native | Nothing to build |

## Feed card (FmTopicCard) — 3A, via the topic-cards component

**2026-09-27:** the card is Discourse's official `discourse-topic-cards`
component (theme 37, child of 36; 03), scoped as a **lightweight discovery
preview**: thumbnail, title, excerpt, author, likes, replies and age, as the
component renders them. The like toggle is the one card action (accepted
exception, 2026-09-27); Save/bookmark and share belong to the topic screen
(3D). Cards also render on category, subcategory and suggested lists, on
purpose.

| Element | Source | Detail |
|---|---|---|
| Category path, author, age | Component | Core's category link; author row (`topic-card__op`, name unless core's `prioritize_username_in_ux` is on (`lib/settings.js:3`)); age is core's activity cell (`show_activity`) |
| Title, read/unread colour | Variable | `--title-color`, `--title-color--read` |
| 2-line excerpt | Component | `.topic-card__excerpt`; the component's `about.json` sets `serialize_topic_excerpts` |
| Thumbnail | Component | Its thumbnail cell from core's `thumbnails` payload — left on desktop, full width above on phones. The pack's right-hand 3:2 is dropped: the component's placement stands |
| First-post likes | Component | Its like toggle (`serialize_topic_op_likes_data` via its `about.json`) — the one card action, an accepted exception; tooltip/error strings are the component's (03) |
| Reply count, new dot, new-replies badge | Component, Native | Core's replies cell with the component's comment icon (`show_reply_count`); badges and row state classes are core's (02) |
| Bookmark and share buttons on the card | **Drop** (decided 2026-09-27) | Not card actions. Core's native bookmark and share stay on the topic screen — Phase 3D |
| Card layout itself | Component | The component's stylesheet; this theme adds only a phone overflow fix (03) |

## Topic (04 Topic, FmPost) — 3D

Mapped 2026-09-27 against core's **nested** topic view, which the site uses
(`nested_replies_enabled`, `nested_replies_default` on; sort `top`; depth 3;
05). The pack draws core's flat stream; where the two differ, the nested
view stands (user's decision).

| Element | Source | Detail |
|---|---|---|
| Title, status, category | Native (2B) | `.nested-view__header` › `h1.nested-view__title`, `TopicCategory` |
| Title and body type (Roboto Slab / Source Sans) | Setting | `heading_font` = `roboto_slab`, `base_font` = `source_sans_pro` (set 2026-09-27, 05) |
| Tags under the title | Drop | Tags are off (Q6) |
| First post card, author, avatar, age | Native | `.nested-view__op-article.boxed`; core's post header |
| Post actions: like, copy link, bookmark, ⋯, reply | Setting | `post_menu` order; `post_menu_hidden_items` = `flag\|edit\|delete\|admin`, so bookmark (Save) shows on every post (2026-09-27). Like doesn't show on your own posts (core) |
| Topic map (created, last reply, replies, users, likes) | Native | `.nested-view__topic-map` — core shows what it has (views, replies…) |
| Topic actions: Bookmark, Share, Tracking, ⋯ | Native | `.nested-view__topic-actions`: Share, Bookmark, Flag, notification level (admin wrench for staff) |
| Reply button | Native | Post reply buttons; `.nested-view__floating-actions` is core's sticky bar (notification, admin, Reply) at `bottom: 0`, lifted above the bottom bar on phones (`nested-view.scss:362,1519`) — it floats over text while scrolling, by core's design |
| Flat chronological stream, reply-to tab | Drop | Nested view: replies nest under their parent to depth 3, with core's depth lines and collapse; sort selector (Top by default) |
| Desktop timeline, mobile "1 / 18" position button | Drop | The nested view has neither (`components/nested.gjs`) |
| Signed-out "Log in to join the discussion" box | Drop | Not a core string. Signed out, Reply opens core's login page; like asks to sign up or log in (core) |
| Suggested topics | Native (3A) | `.more-topics__container`, cards from the topic-cards component |

## Composer (06 Composer) — 3E

Mapped 2026-09-27. The pack says "the native composer"; it is.

| Element | Source | Detail |
|---|---|---|
| Docked, resizable composer on desktop; full screen on phones | Native | `#reply-control`; the theme aligns the docked composer with the 840px column (03) |
| "Create a new Topic" header, minimise, close | Native | Core's composer header (site text) |
| Title field | Native | `#reply-title`, core placeholder |
| Category chooser, prefilled from a category | Native, Built | Core prefills from its New Topic button; the bottom bar's New Topic now passes the page's category the same way (03) |
| Optional tags | Drop | Tags are off (Q6) |
| Markdown body + live preview side by side | Setting | `default_composition_mode` 1: core's rich text editor, so no preview pane is needed; one click switches to Markdown (and its preview) |
| Formatting toolbar, "More options" | Native | Core's toolbar; advanced items under "Options" |
| Create Topic, Cancel, "saved" | Native | Core's submit button, Discard, draft status |
| Mobile "You must choose a category" error | Native (not reachable) | Core's validation; uncategorized is off and a default composer category is set |
| Redesigned composer | Not used | `enable_composer_redesign` is a hidden upcoming change at *conceptual* status |

## Screens 05, 07 (search, profile)

Not mapped yet. They're Phase 5; each gets mapped in its phase.

## Topic and profile context header — 2B

| Element | Source | Detail |
|---|---|---|
| Topic title, status, edit | Native | `.nested-view__header` › `h1.nested-view__title` (`components/nested/header.gjs`); nested view is the site default (05) |
| Topic category | Native | `TopicCategory` › `.topic-category`, core badge |
| Profile identity, bio, actions | Native | `section.user-main` › `.about.collapsed-info` — avatar, names, bio/location when expanded, Admin/Expand |
| Profile tabs | Native + 2C | Core's user nav pills, styled by the shell's `.nav-pills` variables; secondary nav is core's `horizontal-overflow-nav` |
| Same 840px column as lists | Variable | `--d-max-width: 840px` on `body:has(#topic.nested-view)` and `body:has(section.user-main)`; flat topic view keeps core's width for its timeline |
| Topic/profile counts beyond core | Drop | Nothing invented |

## Categories page (02 Categories) — 3B

Direction chosen 2026-09-27: the desktop "categories and latest topics"
concept. The mockup file wasn't readable from the implementing session, so
this maps the concept's named elements to core.

| Element | Source | Detail |
|---|---|---|
| Two columns: categories, latest | Setting | `desktop_category_page_style` = `categories_and_latest_topics` → `.categories-and-latest` (`components/categories-and-latest-topics.gjs`). Desktop only |
| Category name, colour | Native | `CategoryTitleLink` in `td.category` (`parent-category-row.gjs`) |
| Description | Native | `description_excerpt`, shown only when present (4 of 12 top-level categories today) |
| Subcategory links | Native | `SubCategoryItem` list in the row |
| Topics / week | Native | Core's stat cell (`models/category-list.js`): one period for the list; a quiet category falls back to its all-time count without a unit |
| Latest topics column | Native | `CategoriesTopicList` `@filter="latest"` |
| Column heads | Native | Core strings, rendered through the existing site-text overrides |
| Phones: category directory | Setting | `mobile_category_page_style` = `categories_only` (2026-09-27) — no featured-topic stacks |
| Compact Latest rail | Theme | CSS on core's `.latest-topic-list-item` inside `.categories-and-latest`: 24px avatar, 2-line title at body size, tighter rows; same links (03) |
| Member / watcher / online counts | Drop | Not in the payload (Q4) |
| Column widths beyond 840px | Kept | Two 393px columns inside the list column; the rail was compacted instead of widening the page |

## Content frame — width

The pack aligns the header, context header and content to an 840px column,
with topic posts at 690px and the timeline beside them. Core's topic grid
needs about 45 + 690 + 22px plus the timeline, and core picks the timeline
by viewport (`MIN_WIDTH_TIMELINE = 925`, 02), not by container width. So
840px on topic pages would squeeze the timeline. The theme sets 840px on the
list pages only (`body.navigation-topics`, `.navigation-category`,
`.navigation-categories`, from `components/discovery/navigation.gjs`), and
the header's `.wrap` narrows with it. Topic width is 3D's decision.

## Content frame — states (2D)

Checked against `7b4f0970` and in theme 36, signed in, 2026-09-26. The pack
doesn't draw these states; core's own treatments stand unless they break the
journey.

| State | Source | Detail |
|---|---|---|
| Route loading | Native, setting | `page_loading_indicator` = `slider`: the 3px bar in `--tertiary` (`common/loading-slider.scss`). Past the still-loading delay core swaps the outlet for `.route-loading-spinner` (`components/loading-slider-fallback-spinner.gjs`); the body class, and so the 840px column, stays |
| Pagination | Native | `DLoadMore` infinite scroll, `DConditionalLoadingSpinner` in `footer.topic-list-bottom` (`components/discovery/topics.gjs`) |
| New topics arrived | Native | `.show-more > .alert.alert-info` above the list, core's count string |
| Empty list, member | Native, two fixes | `EmptyTopicFilter` → `DEmptyState` (`components/empty-topic-filter.gjs`, `ui-kit/d-empty-state.gjs`, `components/empty-states.scss`); signed in and all loaded only. Its "browse latest" button kept `f=tracked`; the Tracked filter now clears it (03). On phones the picture is capped (`min(65vw, 10rem)`) so the button clears the bottom bar (03) |
| Empty list, signed out | Theme, core's component (4.5, 2026-09-30) | Core renders nothing without a current user (`discovery/topics.gjs`). Off-topic Discussions is empty for visitors (its About topic is unlisted). `fomio-visitor-empty-list.gjs` renders core's `DEmptyState` in `topic-list-bottom__after` with Latest, Categories and Hot as the ways out (03) |
| End of list | Native | Dismiss buttons for members; on mobile core floats Dismiss (`uc-dismiss.scss`) and lifts it by `--footer-nav-height` under `.footer-nav-visible`, which the bottom bar sets |
| Error / not found | Native | In-app: `templates/exception.gjs` (`.error-page`, retry buttons). Server 404: search box and recent topics — already a way on, which 4.5 asks for |
