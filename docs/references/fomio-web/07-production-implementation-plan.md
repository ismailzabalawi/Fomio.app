# 07 — Production implementation plan

Status: active, based on the Fomio mockup pack and the repository state on
2026-09-26. This plan governs implementation after the information architecture
and mockups; it does not treat a mockup as proof of a Discourse capability.

## Product and terminology constraints

- Discourse remains the application: data, routes, permissions, native
  navigation, composer, search, notifications, and moderation stay with core.
- The existing site-text overrides remain active and unchanged for now. The
  theme must never duplicate their visible wording as literals. Core
  translations must be rendered through Discourse's i18n system so its current
  site-text override remains the source of truth and future text changes remain
  manageable in Discourse.
- Where no core string exists for a genuinely theme-owned control, first check
  whether the control can use a native label or icon. If a theme string is
  necessary, put it in the theme locale and document why it is not a core
  string. Never encode it in a template or JavaScript literal.
- The Claude Design screens are visual references only. Reuse a pattern only
  when it fits native Discourse markup, supported APIs, and the frozen
  architecture in [00 — Roadmap](00-roadmap.md).
- Keep v1 sidebar-free, avoid custom search/notification/composer engines, and
  follow the setting → native behavior → theme → component ladder.

## Phases and exit criteria

### 0. Reconcile decisions and establish the baseline

**Work**

1. Keep the decision record aligned across `CLAUDE.md`, the roadmap, and the
   Phase 1 checklist: existing text overrides stay as-is; do not revert or edit
   them as part of theme implementation.
2. Confirm the server's Discourse commit/version still matches the core export
   used by `docs/02-discourse-core-reference.md`. Check the active theme,
   current mobile bottom bar, site settings, current text overrides, and the
   paths and behavior of the screen pack.
3. For every proposed screen element, record whether it comes from a setting,
   native core behavior, existing markup, an allowed outlet, or a justified
   theme component. Remove or revise mockup-only elements that cannot be
   grounded in one of these.
4. Capture a baseline on an isolated, non-default theme preview so later
   changes can be compared without affecting visitors.

**Exit when** the decision records agree, all existing overrides are preserved,
the reference core version is known, and the implementation surface for each
launch screen is mapped to core.

**Status 2026-09-26:** Phase 0 complete and uploaded to preview theme 36
(user-reported). Core version confirmed (`7b4f0970`); palette and fonts decided
(01); shared parts and Home card mapped in [08](08-mockup-core-map.md).
The preview remains isolated from the site default. *(2026-09-27: the default switched between 31 and 36 during the day; check before assuming.)*

### 1. Finish and harden the shared shell (Phase 2)

The mobile bottom bar (2A) already exists. Stabilize it before adding more
surface styling.

**Current progress 2026-09-26:** 2A visual alignment and the first shared-shell
rules for shape, nav pills, and list-page width are in the theme and uploaded to
preview theme 36. The live preview still shows Discourse's native topic-list
layout; the Home card feed and context header are not implemented yet.

The user verified the mobile bottom bar in the preview. This confirms its
mobile presentation only; the remaining 2A route, permission, keyboard, and
iOS PWA checks are still open.

**2B progress:** category/subcategory context uses core's `category-heading`
outlet only when a logo-led native heading is absent. Core continues to own the
accessible heading, breadcrumbs, notification controls, and create-topic
action. The final implementation was uploaded to preview theme 36 and rendered
without a theme error on a parent category with a description (`general`), a
subcategory with a description (`interesting-finds`), and a parent without a
description (`technology`). The logo case is verified against core source only;
there is no live category with an uploaded logo to exercise it.

The initial version was superseded after visual review because it introduced
an extra heading element. The final component renders core's own
logo-heading markup minus the logo (`.category-heading__content`,
`d-category-badge`, `p.category-heading__description`), so core styles it and
no extra heading element sits beside the sr-only `h1`. It imports
`discourse/ui-kit/helpers/d-category-badge`; the subcategory's parent is marked
by the core split-square badge and named by the native breadcrumb. Guards pass
against the pinned `7b4f0970` export. Topic and profile context: done 2026-09-27 (item 2 below).

1. **2A — Bottom bar:** verify the existing `below-footer` implementation,
   permissions, translated labels, active states, safe-area spacing, composer
   and admin/auth exclusions, keyboard behavior, and iOS PWA interaction with
   core footer navigation. Fix only observed issues.
   **Checked 2026-09-26, signed in (admin) on theme 36 at 375px and 320px.**
   Active states match 03 on `/latest`, `/hot`, `/categories`, a category, a
   subcategory, own and another member's profile, a topic, search; `/admin`
   hides the bar and restores core's hamburger; Notifications opens and closes
   core's user menu (`aria-expanded` follows), which slides over the bar as
   core's full-screen panel with its own dismiss; Tab reaches each item in
   order with the `:focus-visible` outline. Fixed, as observed (detail in 03):
   Profile's label 4px low and button labels 1px off; "Notifications" cut off;
   Categories' `aria-current` on every category list; **the bar stayed up
   while the composer was open** (the composer state wasn't reactive); and
   **a minimized draft sat hidden under the bar** (now lifted above it, as
   core does on iOS). Still open: signed-out bar (can't sign out the user's
   session), auth-route exclusion, safe-area inset and the iOS PWA
   double-nav, which need a real device.
2. **2B — Context header:** style existing category, subcategory, topic, and
   profile identity/metadata/actions using core markup. Do not insert a second
   application header or invent unsupported counts.
   **Topic and profile done 2026-09-27.** Both already render a complete
   native context header: the nested topic view (`nested_replies_default` is
   on, 05) has `.nested-view__header` — status, `h1` title with edit, and
   `TopicCategory` (`components/nested/header.gjs`); every profile tab has
   `section.user-main` › `.about` — avatar, names, bio/location when
   expanded, Admin/Expand controls — then core's tab row (already the 2C
   pills). Nothing was missing, so nothing was added. What didn't match the
   grammar was the frame: both used core's 1110px, so the global header
   jumped ~135px between a list (840px) and a topic or profile. The theme
   now sets the same `--d-max-width: 840px` via `body:has(#topic.nested-view)`
   and `body:has(section.user-main)` (core sets no body class for either).
   08 had deferred topic width only for the timeline; the nested view has
   none, and the flat view (which has one) doesn't match the selector.
   Verified on theme 36 signed in at 1280px: header 840px at x 220 on
   `/latest`, a category, a topic, profile summary, activity, messages,
   notifications and preferences; topic column 791px inside it; no page
   overflow; core's secondary profile nav scrolls with its own arrows where
   it no longer fits. At 375px nothing changes (the viewport is narrower
   than 840). No markup, strings or data added.
3. **2C — Local navigation:** style native nav pills and add only justified
   links. Verify routes and permissions. Treat the Tracked entry as a
   site-configurable/core-resolved label; no hardcoded wording. Keep the
   default feed state unlabeled unless Discourse supplies a label.
   **Tracked built 2026-09-26** (`fomio-tracked-filter.js`): core's nav API,
   core's `user.tracked_categories` label, a toggle over the current tab.
   Guards pass, uploaded to theme 36, server compile clean. Not yet seen
   rendered: it shows only to signed-in members, and the preview needs an
   admin session. Still to check there: on → off round trip on Latest, Hot and
   a category; the mobile nav dropdown; keyboard focus.
   **Toggle-off fix (2026-09-26):** the user's preview test showed the off
   link (`/latest`) leaving the page on `?f=tracked`. Off now resets the query
   param explicitly on click. The same item and listener, injected on the
   live site signed out, toggle on and off on `/latest`, `/hot` and
   `/c/general/4`, at desktop width and through the mobile dropdown; the
   underlying tab stays active. The plain-href version also worked there, so
   the original failure is specific to the signed-in preview and still needs
   the user's re-test on theme 36.
   **Signed-in re-test done (2026-09-26, admin session, theme 36):** on → off
   round trips on `/latest`, `/hot` and `/c/general/4` return to the plain URL
   with the underlying tab still active.
   **Open — Hot and Top ignore Tracked.** At `7b4f0970`, `TopicQuery#list_hot`
   and `list_top_for` call `create_list(:hot|:top, …)`, which sets
   `options[:filter]` first; `default_results` merges `f` in, but the check is
   `options[:filter] || options[:f]`, so `:hot` wins
   (`lib/topic_query.rb:369,378,565-567,810,964-981`; mechanism corrected
   2026-09-27).
   Live: `/latest.json?f=tracked` and `/new.json?f=tracked` return 0 topics for
   a member tracking nothing; `/hot.json?f=tracked`, `/top.json?f=tracked` and
   a category's Hot return the unfiltered list. The pill shows as on over an
   unfiltered Hot, and `/` is Hot. Needs the user's decision (hide the pill on
   Hot/Top, send it to Latest from there, or accept).
4. **2D — Content frame:** establish readable width, spacing, and shared
   treatments for existing streams, lists, loading, empty, and error states.
   **Done 2026-09-26.** Each state was traced to core and checked in theme 36
   signed in (state table in [08](08-mockup-core-map.md)). Width: header,
   controls, list and footer share the 840px column at 1280px. Loading
   (`page_loading_indicator` = slider, with core's fallback spinner),
   pagination (`DLoadMore` infinite scroll), empty lists (`EmptyTopicFilter`),
   in-list alerts and errors (exception page; the server 404 already offers
   search and recent topics) all render natively inside the column, on
   desktop and at 375px with the bottom bar. No CSS was needed. One defect
   fixed: the empty Tracked list's "browse latest" button kept `f=tracked` and
   reloaded the same empty list; it now opens Latest unfiltered
   (`fomio-tracked-filter.js`). Verified in theme 36 with scripted clicks on
   `/latest?f=tracked` and `/c/general/4/l/new?f=tracked`, and one real tap at
   375px; `/unread` without the filter keeps core's behaviour (a legacy URL under Unified New — see the re-baseline below; `/new?subset=replies` is its equivalent and behaves the same). Acceptance
   tests added in `test/`, not yet run (no dev instance; 04). Not checked:
   the in-app exception page with theme 36, and a clean measurement of the
   last row above the bar at the end of a list.
5. **2E — Responsive rules:** adapt the same screen structure across desktop,
   tablet, and mobile; do not make a parallel mobile information architecture.
   **Done 2026-09-26.** The user chose a scrolling tab row over core's mobile
   dropdown (roadmap: "compact, horizontal tabs"). Core's
   `navigation-bar-dropdown-mode` transformer returns `false`
   (`fomio-mobile-tabs.js`); below `sm` the pills take their own row and
   scroll sideways, and the actions end flush right at every width (03).
   Verified on theme 36, signed in: at 375px and 320px on `/latest`, `/hot`,
   `/new`, `/categories`, `/latest?f=tracked`, a category, a subcategory and
   a category's Hot — no dropdown, no page overflow, active tab and Tracked
   on-state visible (Home's row overflows by 29px at 375 and 84px at 320 and
   scrolls); real taps turn Tracked on and off and switch to Hot; the
   active-tab reveal brings an off-screen tab in from either side without
   scrolling the page; no console errors. At 700, 768, 1024 and 1280px the
   desktop layout is unchanged except that a wrapped actions row now ends at
   the column edge; header and list keep the 840px column from 1024 up. The
   server compiled the new `@use "lib/viewport"` without theme-field errors.
   Not checked: a real touch device's swipe on the tab row, and RTL.

**Phase 2 closure pass (2026-09-27).**

- *2D, phone empty state:* core sizes the empty list's picture by viewport
  (`8vh` above, `65vw` wide), which left core's "browse latest" button 18px
  above the bottom bar at 375×667 and under it on shorter visible heights
  (Safari toolbars). While the bar shows, the theme caps it at
  `min(65vw, 10rem)` with `--space-4` above. Measured on theme 36 with the
  preview notice hidden to match a visitor: the button clears the bar by
  125px at 375×667 and 11px at 375×553; scrolled to the end, core's tip line
  clears it by 115px; desktop keeps core's 200px picture and 7rem padding.
  Same on `/new`, `/new?f=tracked&subset=replies` and `/latest?f=tracked`.
- *Tests:* `test/acceptance/fomio-tracked-filter-test.js` gains Unified New
  cases (`needs.user({ unified_new_enabled: true })`): the New subset
  survives Tracked on/off; switching subset keeps Tracked; on mobile the
  pills are inline and the subset survives. Not run — needs a development
  Discourse (04).
- *Comment:* the bottom bar's Home comment names `/new` with its subsets;
  legacy `/unread` noted as still routing.
- *Left open, by instruction:* Tracked on Hot/Top (product decision).
- *External acceptance checks — not done here, need real devices or
  settings:* safe-area inset on a notched iPhone (bar, lifted draft
  composer); iOS home-screen PWA, where core's own footer nav may also show;
  touch swipe on the phone tab row and the profile's secondary nav; RTL
  (tab-row scroll direction, flush-right actions become flush-left, the
  active-tab reveal's math). Also still unverified by this pass: the
  signed-out bar and its auth-route exclusions (the 3A signed-out row covers
  cards, not the bar).

**Unified New re-baseline (2026-09-27, before Phase 3).** Unified New is on
for meta.fomio.app (auto-promoted `stable` upcoming change; staff plan to
make it Permanent). Evidence and core paths in 02. Checked on theme 36,
signed in, at 1280px and 375px:

- `/new` shows core's All · Topics · Replies subtabs under the tab row, in
  the 840px column; at 375px under the inline tabs and actions, full width,
  no overflow.
- Tracked keeps `subset` both ways (`/new?subset=replies` →
  `?f=tracked&subset=replies` → back), because its href and off-reset only
  touch `f`/`filter`. The server applies Tracked to all three subsets.
- The empty-state intercept still only catches core's "browse latest"
  label; it lands on plain `/latest` (no `f`, no `subset`). Core's
  subset-switch buttons are untouched.
- Legacy `/unread` still routes, with no active tab and no subtabs. Nothing
  in the theme links it; the bottom bar lights Home there as before.
- No theme code, test or fixture assumes `unread`; only docs did (updated).

Risks, none needing code now: (1) with Tracked on, core's subtab counts
aren't Tracked-filtered while the New pill's is (core inconsistency; don't
patch); (2) on phones the actions row sits between New and its subtabs;
(3) Hot/Top ignore Tracked (open, above); (4) acceptance tests run as a
non-unified member unless `needs.user({ unified_new_enabled: true })` —
proposed, not yet added. Proposal awaiting the user in the session report.

**Exit when** global and local navigation have one clear source each, core
routes/actions still work, the shared context/content patterns are consistent,
and no existing site override is shadowed by theme text.

### 2. Implement the core participation journey (Phase 3)

Implement one surface at a time, in this order, validating the real core
behavior after each change:

1. **Home feed (3A):** begin with the native latest/hot streams and topic-list
   payload. Add a card treatment only if it can restyle the native list or use
   a verified transformer. Use native topic data (including first-post likes
   where available); no invented ranking, views, or follower counts.
   **Status 2026-09-27: cards live in preview 36 through the official
   `discourse-topic-cards` component** (theme 37, child of 36 only; settings
   and reasons in 03). Core at `7b4f0970` has no card component or API, and
   Horizon's card only loads with Horizon active, so the component is the
   native route (user's decision). A first, custom card built on core's cells
   (`fomio-topic-cards.js`) was removed the same day, with its CSS and the
   `serialize_topic_excerpts` modifier (the component brings its own).
   **Verified** signed in (admin) on theme 36, desktop (1024px) and 375px:
   cards on Latest, Hot, a category, a subcategory (2B context intact) and
   suggested topics; thumbnails, excerpts, author, like button, reply count
   with icon, age; no "Published"; clicking or tapping a card's excerpt or
   empty space opens the topic; no horizontal overflow after one fix (03); no
   console errors; the four guards pass against a fresh `7b4f0970` export.
   Theme 36 pushes from `discourse_theme watch` keep 37 attached.
   **Scope (decided 2026-09-27):** cards are lightweight discovery previews.
   They keep the component's native thumbnail, title, excerpt, author,
   likes, replies and age (with core's category link), laid out as the
   component lays them out. Save/bookmark and share are **not** card actions;
   they stay on the native topic screen (3D). The pack's card bookmark and
   share buttons, and its right-hand thumbnail, are therefore dropped for
   cards, not open.

   **Accepted exceptions (user's audit decisions, 2026-09-27):**
   1. **Likes/reactions are the one card action.** The component's like
      toggle (first post, core `post_actions`, core permissions) stays on
      cards on purpose. Save/bookmark and share remain topic-screen actions
      (3D).
   2. **Cards on every native list, not only Home.** The component stays
      enabled on Home's lists, category and subcategory lists, and suggested
      topics (`show_on_categories` empty, `show_for_suggested_topics` true).
      Intentional: it gives 3B/3C the same card grammar.
   3. **Theme 37 stays the upstream external component** until a Fomio-owned
      fork replaces it; upstream updates are applied by hand (03). It is
      attached to theme 36 only. Decided while 36 was a preview; the user
      made 36 the site default on 2026-09-27 for the signed-out check; the site default switched between 31 and 36 more than once that day (36 again at the 3B check), so check `/admin/themes.json` before assuming 36 and 37 are live.

   **3A acceptance criteria.** 3A is done when all of these hold on theme 36:
   - Cards come only from the `discourse-topic-cards` component attached to
     the theme; the theme adds no card markup, card initializer or card
     layout — only fixes to what the component renders (03).
   - Each card shows the native thumbnail (when the topic has one), title,
     excerpt, author, likes, replies and age, and nothing else the component
     or core doesn't render.
   - No card has a Save/bookmark or share control, and none is added by
     theme code.
   - Selecting a card (its title, excerpt or empty space) opens the topic,
     where core's own bookmark and share actions are available.
   - Cards render on Home's lists (Hot, Latest, and with Tracked on), a
     category, a subcategory, and suggested topics.
   - Desktop and phone (375px) both work: no horizontal overflow, the bottom
     bar doesn't cover content.
   - Signed out: cards render and open topics; likes don't act without an
     account (core permissions).
   - Light and AMOLED palettes, and keyboard: a card's title link is
     reachable and visibly focused.
   - The only card action is the like toggle (exception 1); pressing it is
     not part of the check on the live site.
   - No theme strings; the component's own strings are limited to the like
     button's tooltip and error messages (accepted exception, 03), and
     "Published" stays off.
   - The four guards pass against the server's core export.

   **Results, 2026-09-27** (admin session, theme 36 + 37, desktop 1024px and
   375px):

   | Criterion | Result |
   |---|---|
   | Component-only cards | **Pass.** No card initializer or markup in the theme; two CSS fixes only (03) |
   | Content set | **Pass.** Thumbnail (when present), title, excerpt, author, likes, replies, age; "Published" off |
   | No Save/bookmark or share | **Pass** |
   | Opens the topic | **Pass.** Click on empty space, tap on the excerpt, and keyboard Enter on the focused title all open the topic |
   | Lists | **Pass.** Hot, Latest, a category, a subcategory, suggested topics. **Tracked on:** General was set to Tracking on the admin account with the user's permission, checked (30 cards, all Interesting Finds, a General subcategory; desktop and 375px, no overflow), then set back to Regular (1); the account again tracks and watches nothing. With nothing tracked, core's empty state renders |
   | Desktop and 375px | **Pass.** No horizontal overflow after the excerpt fix; the bottom bar clears |
   | Signed out | **Pass (2026-09-27, after the user made 36 the site default).** Checked in a fresh headless Chromium profile with no cookies (Playwright's cached `chrome-headless-shell` 1243, driven over DevTools; script kept outside the repo). No `.current-user`; themes 36 and 37 loaded. Latest at 1024px and 375px in light and dark, plus Hot, a category and a subcategory: 30 cards each, 0 enabled like buttons (`op_can_like` is false without a user, and the component disables its button on it), no bookmark or share control on any card, no overflow; Sign Up and Log In in the header; the bottom bar shows Home and Categories on phones. A real click on a card's excerpt opened that topic, readable signed out with Log In and Reply offered. While 36 was only a preview this was blocked: core applies `preview_theme_id` for staff only (`lib/guardian.rb:621`) |
   | Light palette | **Pass.** Theme 36's light scheme "Fomio" (36), shown by flipping the page's scheme stylesheets in the browser only (no cookie written): white surface, violet active pill and New Topic, cards with core's card shadow |
   | AMOLED palette | **Pass (2026-09-27).** "Fomio AMOLED" (38) assigned as theme 36's dark palette (`dark_color_scheme_id` 38, authorized by the user). Signed out with `prefers-color-scheme: dark`, the page loads scheme 38 (`--secondary` #000000, `--tertiary` #a58fff): cards readable on true black at 1024px and 375px, like buttons disabled, no overflow. A member's own dark-palette preference overrides the theme's: the admin account keeps `dark_scheme_id` 32 and still sees scheme 32; that preference was not changed |
   | Keyboard focus | **Pass after one fix.** Tab reaches the thumbnail link (browser focus ring) then the title (accent colour, underline, card marked `.selected`), and Enter opens the topic. Core's keyboard bar also matched the component's nested stats cell and drew a stray bar beside the like button; fixed in theme CSS (03). Checked signed in in the light palette and scheme 32, and signed out in AMOLED with real Tab presses: category, author, replies and age links are reachable, the disabled like button is skipped, the focused card is outlined and its title underlined |
   | Strings | **Pass.** Only the like button's tooltip and errors are component strings |
   | Guards | **Pass** against a fresh `7b4f0970` export |

   **3A signed off 2026-09-27.** Every criterion passes. Accepted
   exceptions: likes are the one card action; cards on every native list;
   theme 37 is the upstream component until a Fomio fork. Not tested on
   purpose: pressing the like button on a live post (its permission gate is
   checked signed out).
2. **Category and subcategory (3B–3C):** shared context pattern, category
   hierarchy, and native category topic lists. Do not add watcher totals.
   **3B started 2026-09-27.** Already in place: 2B's category context (name,
   colour, description), core's breadcrumbs (a subcategory's siblings are in
   its breadcrumb dropdown), the tab row with Tracked (2C/2E), core's
   notification button and New Topic, and 3A's cards on every category list.
   **User's decisions (2026-09-27):**
   - *Subcategory links:* core's own subcategory list, turned on with the
     category settings `show_subcategory_list` = true and
     `subcategory_list_style` = `rows` on the three parents that have
     subcategories: General (4), Off-topic Discussions (9) and Fomio (45).
     Before: false and `rows_with_featured_topics` on all of them. This is
     category data, so default theme 31 shows the list too, in core's style.
     Theme 36 restyles it as one wrapping row of core's category links (03).
   - *Landing tab:* categories keep opening on Latest (`default_view` unset
     on all 28); matches the mockup and Home.
   - *Activity count ("24 topics / week"):* deferred. Category pages carry
     no weekly count (`topics_week` is only in `/categories.json`), and
     `topic_count` excludes subcategories (General shows 3).
   **Verified** on theme 36 (preview, admin session): General at 375px —
   the list was 1,248px tall with the first card at 1,742px in core's rows;
   restyled, 6 subcategories in 112px and the first card at 582px. At
   1024px: one 27px row, first card at 377px. Fomio's 8 subcategories wrap
   to two rows (62px); Off-topic shows its one; subcategory pages show no
   list (core only lists a parent's). The visually hidden column heads still
   label the list (`aria-labelledby`). Keyboard: Tab from the notification
   button reaches the first chip (browser focus ring) and Enter opens that
   subcategory. No horizontal overflow; `/categories` unchanged (the rule is
   scoped to `body.navigation-category`); the four guards pass.
   **Signed out and light palette — pass (2026-09-27).** Theme 36 was the
   site default at the time (checked in `/admin/themes.json`), so a fresh
   headless Chromium profile with no cookies saw it as a visitor does
   (themes 36 + 37, no `.current-user`). General, at 1024px and 375px, in
   light ("Fomio", 36, white) and dark ("Fomio AMOLED", 38, black): 6
   chips, the same 6 subcategories `/categories.json?parent_category_id=4`
   returns to a visitor, 27px tall on desktop and 112px on phones, no
   visible descriptions or counts, no overflow, first card at 250px
   (desktop) / 422px (phone). Fomio at 375px, light: 8 chips (8 for a
   visitor), 232px. Off-topic at 1024px, light: 1 chip ("Random").
   Readability: chip text computed rgb(91, 88, 105) on white and
   rgb(172, 167, 189) on black (core's badge colour); ring is
   `--content-border-color`. Keyboard, signed
   out: Tab reaches the first chip (browser focus ring) and Enter opens
   Interesting Finds; a real tap on the last chip at 375px (dark) opens
   Ideas. The signed-in light palette was checked earlier the same way as
   3A (scheme 36).
   **Found, not a 3B defect:** signed out, Off-topic Discussions shows its
   chip row and then nothing — the category has 0 topics a visitor can see
   (`topic_count` 0; its About topic isn't listed), and core renders nothing
   for an empty signed-out list (2D). That's Phase 4.5's "no bare Nothing
   here" gap, or content.
   **Categories page direction (2026-09-27, user's decision):** follow the
   mockup's *02 Categories* desktop concept — core's native "categories and
   latest topics" layout. Config: `desktop_category_page_style`
   `categories_boxes` → `categories_and_latest_topics` (core's default),
   changed live with the user's explicit go-ahead (Admin API as the admin
   session; HTTP 204; read back). Theme: **no change** — every element the
   concept names is core's own row layout (`categories-and-latest-topics.gjs`
   → `categories-only.gjs` › `parent-category-row.gjs` +
   `categories-topic-list.gjs`): category link, real description excerpt
   (only where the category has one), native subcategory links, core's
   stat cell, and the Latest column. The mockup file itself wasn't readable
   from the session (no design MCP), so no further styling was attempted.
   **Verified on theme 36 (admin preview) at 1280px:** `.categories-and-latest`
   fills the 840px column as two 393px columns; 12 category rows, 19 latest
   topics; header labels are core strings (rendered through the existing
   overrides as "Hub" / "Bytes"); no overflow. **375px:** unchanged — phones
   use `mobile_category_page_style` (`categories_with_featured_topics`); 12
   items, bottom bar present, no overflow. Not checked: signed out, light
   palette, keyboard.
   **Payload limits (document, don't invent):** only 4 of 12 top-level
   categories have a description (general, fomio, staff,
   off-topic-discussions), so most rows show none until admins write them. The stat cell is core's:
   one period for the list (week, else month); a category with 0 in that
   period shows its all-time count with no unit and the sentence as a
   tooltip (`models/category-list.js:62-97`) — Fomio and Staff read "2",
   Off-topic "0". No member, watcher or online counts exist (Q4).
   **Audit fixes (2026-09-27, user's decisions):**
   - *Phones:* `mobile_category_page_style` `categories_with_featured_topics`
     → `categories_only` (live, user-authorized; HTTP 204, read back). At
     375px `/categories` is now a directory: 12 categories, 0 featured-topic
     rows, 91px per category without a description (General 223px with its
     description and subcategory links), 1,898px in all, 48 links, no
     overflow, bottom bar on Categories.
   - *Desktop Latest rail:* CSS on core's `.latest-topic-list-item`, scoped
     to `.categories-and-latest` (desktop-only markup): tighter padding and
     gap, 24px avatar, title cell takes the free width at body size, title
     row clamped to two lines, body-size reply count (03). Rows went from
     81–183px to 83px (62px for a one-line title); the rail is 1,590px
     beside a 1,645px categories column; the title cell grew 235 → 319px.
     Every row keeps its 5 links — avatar ("Soma's profile" for AT), title
     (full text in the DOM, clamped only visually), category badge,
     replies, time; Tab reaches the title with the browser focus ring. No
     overflow; guards pass; theme compiles on the server. Theme 36 was the
     site default at upload time, so this is live.
   The page column stays 840px; not changed: global header, welcome banner,
   `top_menu`. ~~Not checked: signed out, light palette.~~ **Checked in the
   Phase 3 audit (2026-09-27):** signed out (fresh headless profile; theme 36
   was the default), 1024px and 375px, light (36) and AMOLED (38): desktop
   `categories-and-latest` with 11 category links (Staff is hidden from
   visitors) and 18 Latest rows at 62/83px; phones the `categories_only`
   directory, bottom bar Home, Categories; no overflow, no console errors.
   **Accessibility smoke test (2026-09-27, signed out, headless Chromium
   AX tree, 1024px and 375px).** Links are named by the subcategory
   ("Interesting Finds" …) inside core's level-3 headings; `display:
   contents` kept core's table semantics in Chromium (desktop: table,
   rowgroup labelled by the "categories.category" head, rows, cells; phone:
   core's one-cell table per subcategory with a `columnheader`, core's own
   markup). Tab order follows the visual order, then enters the topic list;
   the phone row's hidden "N total" links take no focus. Not checked:
   Safari/VoiceOver, which has handled `display: contents` on table parts
   less well — a device check.
   **User's decisions after the audit (2026-09-27):**
   1. *Topics column head hidden.* It was announced over a column whose
      counts are hidden; `thead th.topics` is now `display: none`. The
      category head stays (visually hidden) because it labels the tbody.
   2. *Compact row accepted, member badges kept.* Descriptions and raw topic
      counts stay hidden. Core's "N new" / "N unread" badges
      (`CategoryUnread`, desktop only — core renders none in the phone row)
      show again beside the name: only the unclassed stat div in `td.topics`
      is hidden (03). Checked with a badge inserted into the page only (the
      admin account had none): on the name's line, 8px after it, inside the
      chip, which grows from 27px to 34px while it has one.
   3. *Notification level stays in core's nav row.* Moving it would mean a
      second copy of core's control in the `category-heading` outlet,
      re-implementing core's wiring (indirect mutes, deleted categories,
      signed-in only), hiding the original with CSS, and losing it on
      categories with a logo (the outlet renders nothing there). Core offers
      no setting, transformer or outlet to place it
      (`components/d-navigation.gjs:428-440`).
   **Off-topic blank list — pre-existing, not 3B.** A visitor's Off-topic
   list is empty: its About topic (`/t/18`) is unlisted (`visible: false`,
   staff see it), and "Random" (34) holds only its own About topic, listed
   in Random's list. Core renders no empty state without a signed-in user
   (`components/discovery/topics.gjs:130`), and core fetches the topic list
   without reading the subcategory setting (`build-category-route.js`,
   `_retrieveTopicList`). Content, or Phase 4.5.
   **3B closed 2026-09-27.** Guards pass.

   **3C — subcategory page (2026-09-27): native, nothing built.** The page
   already uses the category design: 2B's context header (core's badge with
   the split square that marks the parent, the description), core's
   breadcrumbs, the tab row, 3A's cards. Core shows no subcategory list here
   (it lists only a parent's), as intended.
   **User's decisions:** *no parent link in the header* — the parent stays
   reachable through core's breadcrumb dropdowns (the second one's "remove
   filter", site text, opens the parent); *no sibling row* — the pack's
   "Also in …:" line is dropped, because core's second breadcrumb dropdown
   already lists the siblings, core has no string for "Also in", and a
   theme-built list would duplicate it.
   **Verified** on Interesting Finds (11). Signed out (theme 36 was the
   default; fresh headless Chromium profile, no cookies), at 1024px and
   375px, light (36) and AMOLED (38): header with the subcategory's badge,
   parent square and description; breadcrumbs General › Interesting Finds;
   tabs Hot, Latest; 30 cards; phone bar Home, Categories; no overflow.
   Keyboard, signed out: 9 Tabs reach the second breadcrumb dropdown (named
   "Filter by: Interesting Finds", focus visible); Enter opens it on the
   current subcategory with the siblings listed; ArrowUp twice reaches
   "remove filter"; Enter opens `/c/general/4`. Signed in (preview): tabs
   Hot, Latest, New, Tracked; notification button and New Topic in the nav
   row; 30 cards; no overflow.
   **Known limitation, accepted:** getting from a subcategory back to its
   parent takes a menu, not one click.
3. **Topic (3D):** improve title, first-post reading, metadata, actions, and
   reply-stream readability while retaining core topic navigation and its
   configured ~~flat~~ reply behavior. Save (bookmark) and share are topic-screen
   actions: core's native topic and post controls, never card actions (3A
   scope, 2026-09-27).
   **3D, 2026-09-27: done with settings, no theme code.** Mapping in 08.
   **User's decisions:**
   - *Nested view stays* (`nested_replies_default` on): 3D designs for core's
     nested view. The pack's flat stream, desktop timeline and mobile
     position button are dropped for nested topics (the view has none).
   - *Save on every post:* `post_menu_hidden_items` =
     `flag|edit|delete|admin` (was `flag|bookmark|edit|delete|admin`).
   - *Fonts set:* `base_font` = `source_sans_pro`, `heading_font` =
     `roboto_slab` (were `lora` / `raleway`), as decided in 01. Site-wide:
     theme 31 changes too.
   - *Test content:* with the user's approval, a six-post thread in the
     staff-only Staff category, topic **1409** "[3D test] Nested reply layout
     check" (replies to depth 3), posted from the admin account. Visitors
     get 404 for the category and its topics. Used again for 3E, then
     soft-deleted on 2026-09-27 with the user's confirmation.
   **Verified.** Signed in (preview 36) on 1409 at 1024px: slab title, sans
   body, boxed first post with copy link, edit, bookmark, ⋯, Reply; topic map;
   Share, Bookmark, Flag, Tracking; Top sort; three nesting levels with
   depth lines; bookmark on every reply. At 375px: no overflow, the text
   column narrows from 318px to 262px at depth 3, the floating Reply bar
   sits 16px above the bottom bar. Signed out (theme 36 was the default;
   fresh headless profile) on a public topic (1378) at 1024px and 375px,
   light (36) and AMOLED (38): fonts applied; like asks to sign up or log
   in, copy link, flag by email; Sign Up / Log In in the header; phone bar
   Home, Categories; no overflow; Reply opens core's login page.
   **Known, core's design:** the sticky floating Reply bar covers the lower
   right of the text while scrolling (`nested-view.scss:362`).
   **Not checked:** liking, bookmarking or replying for real (they'd act on
   live posts); a thread with other members' posts (like shows then).
4. **Composer (3E):** make the native composer easier to use through supported
   controls and styling. Do not replace its engine or hardcode field/button
   terminology.
   **3E done 2026-09-27.** Mapping in 08. The composer is core's: rich text
   editor by default (`default_composition_mode` 1 — what-you-see editing,
   so no separate preview pane; one click switches to Markdown), title,
   category (prefilled from a category page), body, core's toolbar with
   "Options" for advanced features, Create Topic / Discard, draft saving.
   Tags are off. Core's own composer redesign (`enable_composer_redesign`)
   exists but is a hidden upcoming change at status *conceptual*; left off.
   **Two changes, both theme code:**
   - *Composer aligned with the column (CSS, 03).* Core lines the docked
     composer up with the content column from 1110px using `--d-max-width`,
     and puts it at .67em below that. With the theme's 840px column the
     composer sat at the window's edge between ~790 and 1110px (measured at
     1024px: composer 11px from the window, column at 92px). Now core's
     formula applies at every desktop width. Measured with the composer
     open, New Topic from a category page: its left edge is 11px (.67em)
     inside the column at 700, 800, 900, 1024 and 1280px and it stays
     within the column; Reply in 1409 at 1024px the same. No overflow.
   - *Bottom bar New Topic uses the page's category (2A component).* It
     called `composer.openNewTopic()` with no category, so on a category
     page the composer opened in the site's default category (General);
     core's own New Topic button passes the category
     (`controllers/discovery/list.js`, `createTopicTargetCategory`). The
     bar now does the same with core's rule (the category if the member can
     post there; else a postable subcategory when
     `default_subcategory_on_read_only_category` is on; else the category).
     Verified at 375px: on Interesting Finds the composer opens in General ›
     Interesting Finds; on `/latest` and on a topic it keeps core's default
     (General), as before.
   **Verified**, signed in (preview), no post submitted: desktop focus opens
   on the title, Tab reaches the category chooser (focus visible) and then
   the toolbar; Escape minimises to core's draft strip; closing an empty
   composer leaves no draft (the account's one draft is from 2026-09-26,
   before this work). At 375px core's full-screen composer, the bottom bar
   hidden while it's open, 9 toolbar buttons in a scrolling row, no
   overflow. Guards pass.
   **Not checked:** pressing Create Topic or Reply through the composer
   (it publishes); the mockup's "You must choose a category" state (core's
   validation; `allow_uncategorized_topics` is off and a default category is
   always set, so it doesn't arise).

### Phase 3 audit — 2026-09-27

Run after 3E, read-only except the checks noted. Theme 36 was the site
default throughout.
- **Configuration read back** and matching these docs: theme 36 default,
  light 36 / dark 38, child theme 37 at `6e74da3` with the recorded
  settings; `base_font` / `heading_font`, `post_menu_hidden_items`,
  nested replies on, `default_composition_mode` 1; `show_subcategory_list`
  + `rows` on categories 4, 9 and 45, `default_view` unset.
- **Signed out** (fresh headless Chromium profile), `/latest`, `/hot`,
  General, Interesting Finds and a public topic, each at 1024px and 375px in
  light and AMOLED — 20 loads: themes 36+37, Source Sans body, Roboto Slab
  topic titles, 30 cards per list with 0 Save/share controls and 0 enabled
  likes, General's 6 chips with no visible descriptions, category and
  subcategory context, 5 suggested cards on the topic, phone bar Home and
  Categories, no overflow, **0 console errors**. Plus `/categories` (above).
- **Signed in** (preview, admin) at 1024px: Home lists 30 cards with
  Tracked; Tracked on shows core's empty state (the account tracks
  nothing); General: 6 chips, topics head hidden, raw counts hidden, 6
  badge boxes kept, notification control in the nav row; Interesting
  Finds: breadcrumbs, Hot / Latest / New / Tracked, no subcategory list;
  topic 1409: nested view, fonts, 6 posts each with Save, 5 suggested
  cards. At 375px: five-item bar, scrolling tabs, 112px chip row, the
  floating Reply bar clear of the bottom bar. No overflow anywhere.
- **Guards:** all four pass against the `7b4f0970` export.

**Composer submission (2026-09-27, user's approval):** in staff-only topic
1409 at 1024px, Reply from the floating bar, the text "Composer submission
check for Phase 3 sign-off." typed into the rich editor with real key
presses, Reply pressed: post 7 created with exactly that text, rendered in
the page, composer closed, no draft left. Topic 1409 was then soft-deleted
with the user's confirmation (`deleted_at` 2026-09-27 19:04 UTC; staff can
restore it).

**Phase 3 signed off 2026-09-27.** 3A–3E are complete and the exit
criterion holds on the evidence above: visitors browse and read everywhere
checked, and a member goes from Home or a category to a topic, replies
through the native composer, and can start a new topic in the right
category — with Discourse's permissions and the existing site-text
overrides throughout.
Carried open, not blocking: Safari/VoiceOver on the chip row;
liking/bookmarking on live posts not exercised; Off-topic's empty
signed-out list (content / Phase 4.5); the 2A device-only checks.

**Exit when** a signed-out visitor can browse and read, and a permitted member
can follow the native path from Home/category to topic to reply or new topic,
with the same Discourse permissions and text overrides respected throughout.

### 3. Complete discovery and activation (Phase 4)

Use native logged-out browsing, signup, category permissions, and category
tracking first. **Decision (2026-09-30):** do not add an interest picker or
admin-set default categories. Let members choose categories and build their
own tracked feeds. Keep discovery on native `/categories`, `/hot`, and
`/latest`; no separate Explore surface or personalized suggestions for launch.
Empty states should lead to existing useful content or actions rather than
fabricated recommendations.

**Phase 4 baseline (2026-09-30):**

| Item | Current evidence | Remaining work |
|---|---|---|
| **4.1 Logged-out browsing** | Phase 3's signed-out audit covered Home, category, subcategory, topic, and Categories at desktop and phone widths. Public visitors read these surfaces without a wall. | Reconfirm current behavior in a clean signed-out session before Phase 4 sign-off; the existing evidence predates the current content/configuration. |
| **4.2 Signup** | Phase 1 records open registration, signup CTA, no invite requirement, no approval requirement, and the shortest signup form as applied. | Verify the current signup entry/return path and the post-signup first step without creating a live account. Social login remains off by decision. |
| **4.3 Interests** | No native picker; `default_categories_tracking` is blank. | **Resolved:** keep defaults blank and let members build their own tracked feeds through native category controls. Verify the first tracked-feed path; no custom flow. |
| **4.4 Suggested communities** | No personalized suggestions are implemented. | **Out of scope for launch:** the native Categories directory is self-service community discovery. |
| **4.5 Empty states** | Member Tracked-empty handling is fixed. A known public gap remains: Off-topic Discussions can have no visitor-visible topics, and core renders no anonymous empty-list state there. | Decide a useful native destination for that case, then verify other empty/low-activity states for visitors and members. |
| **4.6 Explore** | `/categories` gives a category directory and Latest topics on desktop, and a category directory on phones; `/hot` and `/latest` are native topic feeds. | **Resolved:** these native destinations are sufficient for launch; no separate Explore screen or invented popularity/growth metrics. |

The Phase 3 signed-out evidence is useful baseline evidence, not a substitute
for a current clean-session check. This baseline table records evidence and
decisions; implementation status is recorded in the Phase 4 work section.

**Phase 4 work (2026-09-30).** Scope set by the user: no interest-selection
or onboarding flow, no separate Explore screen, no invented recommendations,
metrics or category data; `/categories`, `/hot` and `/latest` are the native
starting points.

- *4.5, visitor empty list — built.* Core renders its empty-list state only
  for a signed-in member (`components/discovery/topics.gjs`,
  `showEmptyFilterEducationInFooter`), so a visitor on a list with nothing
  they can see got the context header and nothing else. New
  `fomio-visitor-empty-list.gjs` renders core's own `DEmptyState`
  (`empty-topic-filter` identifier, core's picture and
  `topics.none.education.generic`) in `topic-list-bottom__after` for
  visitors only, with Discourse's existing lists as the ways out: Browse
  latest topics, then Categories and Hot, dropping the site-wide list already
  showing (details in 03). All labels are core i18n, so the overrides apply.
  Signed-out API sweep of every public category and subcategory: only
  Off-topic Discussions (9) returns 0 topics; Uncategorized (1) also does,
  but uncategorized topics are off. `/latest` and `/hot` each return a full
  page.
- *Went live unintentionally.* A `discourse_theme watch .` started
  2026-09-26 was still running and theme 36 was the site default, so saving
  these files uploaded them to visitors; nothing was uploaded deliberately.
  The whole working tree went with them, including the uncommitted composer
  experiment (inert without `?fomio_composer_preview=1`). See 04.
- *Verified live,* signed out (fresh headless profile over CDP, themes 36+37)
  on Off-topic: 375×812 light, 375×667 AMOLED, 1024×900 light — title, CTA,
  Categories and Hot links; the CTA clears the bottom bar by 176px / 166px;
  no overflow; 0 console errors. The CTA opens `/latest` (30 topics, bar on
  Home); the Categories link opens `/categories` (11 categories). Signed in
  (admin, built-in browser) `/latest?f=tracked`: exactly one empty state,
  core's, no visitor links, 0 console errors. Guards pass against a fresh
  `7b4f0970` export. Acceptance tests added
  (`test/acceptance/fomio-visitor-empty-list-test.js`), not run (no dev
  instance; 04). Not checked: keyboard focus on the tip links, RTL.
- *4.1 re-check (partial).* Signed out, Off-topic, its subcategory row and a
  public About topic (`/t/18`) load without a wall on theme 36. The full
  clean-session pass across Home, category, subcategory and topic is still
  open.
- *4.2 (read-only).* Signed out, `/signup` renders core's form (email,
  username, password; core's honeypot fields) with no login wall. On phones
  the signed-out header shows **Log In only**; Sign Up is desktop-only in the
  header (core behaviour). Nothing submitted, no account created.

**Remaining product decisions (recorded, not built):**

| # | Decision | Notes |
|---|---|---|
| D1 | 4.3 — admin-set category defaults or picker | **Resolved:** neither; keep defaults blank and let members choose categories and build their own tracked feeds |
| D2 | 4.4 — suggested communities | **Resolved:** no personalized suggestions for launch; members browse the native Categories directory |
| D3 | 4.6 — separate Explore screen? | **Resolved:** `/categories`, `/hot`, and `/latest` are sufficient for launch |
| D4 | Off-topic content | Its About topic (`/t/18`) is unlisted; listing it or seeding topics is admin/content work. The theme state now covers the blank either way |
| D5 | Low-activity subcategories | 11 of 15 subcategories show visitors a single topic. Content, not theme |
| D6 | Phone signup entry | Only Log In in the signed-out phone header; the bottom bar has no signup item. Accept core's modal path, or change a setting/theme? |
| D7 | Empty state offers signup? | Not added: it would be a new prompt on a content state. Needs the user |
| D8 | Tracked on Hot/Top | Carried from Phase 2 |

**Exit when** visitor → useful content → category → signup when needed → first
watch/track or post is understandable and usable on desktop and mobile.

### 4. Lightly theme supporting surfaces (Phase 5)

Bring Search, Profile, Notifications, Bookmarks, and Messages into visual
alignment by restyling their native surfaces. Preferences, admin, and
moderation stay native unless a launch blocker is demonstrated. Do not build
replacement search or notifications.

**Exit when** the full launch journey remains visually coherent through
notifications and return visits, without changing core capabilities.

### 5. Release verification and launch gate

Verify on the isolated theme against the same Discourse core version as the
server. Cover current desktop and mobile browsers plus tablet widths, signed-in
and signed-out users, posting permissions, empty/loading/error states, color
schemes, keyboard-only navigation, visible focus, reduced motion, contrast,
safe areas, and iOS PWA navigation. Check that dialogs, composer, topic
timeline, and core header/drawer do not overlap the bottom bar.

Run the repository's existing guards before a release candidate:

```bash
./scripts/check-native.sh
./scripts/check-variables.sh
./scripts/check-scss.sh
./scripts/check-duplication.sh
```

Also perform a manual review against the live site-text overrides and compare
the implemented screens with the mockups. Resolve missing compiled-asset
warnings and confirm that no mockup-only text, sample data, or unsupported
actions entered production code. Record any known gaps and get the user's
release decision before making the theme the site default.

**Launch gate:** a visitor can arrive, understand the current Discourse
wording, find and read a useful discussion, create an account when needed,
participate, receive a notification, and return. All of that works with the
existing override set; the theme does not own duplicate product vocabulary.

## Explicitly out of scope for v1

- Reverting or editing the existing site-text overrides.
- Sidebar or custom global navigation beyond the already approved mobile bar.
- A new feed/ranking algorithm, social metrics absent from core, or custom
  community/member data.
- Replacing the Discourse composer, search, notifications, moderation, or
  routing.
- Building additional features merely because they appear in a mockup.

## Risks to resolve during implementation

| Risk | How the plan addresses it |
|---|---|
| Mockups show labels that differ from live overrides | Core i18n remains the runtime source; compare each actual render against the current override list. |
| A visual pattern needs markup or data Discourse does not expose | Verify against the pinned core export first; simplify or defer instead of adding a backend. |
| Bottom bar conflicts with core navigation or composer states | Validate exclusions and the iOS PWA/footer-nav case before extending it. |
| Card feed becomes a custom parallel list | Start from native topic-list data and justify any transformer against the core version. |
| Visual polish hides permission or accessibility problems | Include signed-out/permission, keyboard, contrast, reduced-motion, and responsive checks in the release gate. |
