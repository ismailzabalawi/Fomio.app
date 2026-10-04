# 00 — Roadmap

**Composer agent entry point:** [13](13-composer-agent-guide.md) ties the
accepted v4 planning roadmap to the IA, researched routes and reuse rules.
Use it before composer work; older prompts and experiments are historical.

**2026-09-30 composer clarification:** design must be locked before
implementation. The earlier theme-38 experiment came from a misinterpretation
of design approval and is paused. The user has requested a v4 implementation
roadmap, not implementation; [12](12-composer-v4-implementation-roadmap.md)
records the design decisions, native feasibility gates and acceptance stages.

**2026-09-29 update:** the user reopened composer exploration following the
new mockups, explicitly including tablets. A limited, opt-in native
feasibility pass lives in preview theme 38; see [11](11-composer-native-feasibility.md).
This does not replace the earlier Phase 3 sign-off or approve a production
rollout. Tablet breakpoint transitions and physical keyboard/touch checks
remain open.

Adopted 2026-09-26, when the project was restarted. The previous attempt
(branch `archive/v0`) grew past what launch needed: a restyled sidebar, a
settings rail, a custom category header, list rows tuned pixel by pixel. This
roadmap replaces it.

**The shift:** we are not redesigning Discourse around a new navigation
system. We redesign the main experience layer and keep as much native
Discourse behaviour as possible.

## Product framing

Fomio is a better community product built on Discourse's proven primitives,
not a clone that replaces them. Communities, posts and discussion stay at the
centre; a member's explicit community choices should matter more than a hidden
recommendation algorithm.

For launch, that means a productised Discourse installation:

```text
Discourse core → configuration → Fomio theme → a small number of justified components
```

Categories give broad domains structure, subcategories give them focus, and
topics hold the conversation. Useful discussions may later become guides, FAQs or community
knowledge, but that is post-launch differentiation — not a new data model to
build now.

## The redesign rule

> We do not redesign a Discourse screen merely because it looks like
> Discourse. We redesign it only when it materially affects the primary Fomio
> experience.

Every piece of theme work has to name the step of the launch journey (below)
it serves. If it can't, it waits.

## The priority ladder

Solve every need at the highest rung that can do it:

```
Setting
↓
Native Discourse behaviour
↓
Theme
↓
Theme component
↓
Trusted plugin
↓
Custom plugin
↓
Custom backend, only if unavoidable
```

## Phases

```
0. Freeze architecture
1. Configure Discourse
2. Build the main-screen framework
3. Build the core journey
4. Build discovery and activation
5. Lightly theme supporting screens
──────────── LAUNCH ────────────
6. Observe and repair
7. Add persistent navigation, if earned
8. Differentiate the product
9. Align the native app
```

### Phase 0 — Freeze the architecture

Locked. See 01 for the list. Nothing here is reopened without the user.

### Phase 1 — Configure Discourse into Fomio

What should Discourse already do for us? Settings and admin work only — no
theme code. The checklist, with setting names verified against the server's
core, is [05](05-phase-1-configuration.md).

- **1.1 Terminology** — Discourse remains the source of product text. The
  existing 69 site-text overrides remain active and unchanged for now, per the
  user's clarification on 2026-09-26. The theme must use Discourse's i18n
  output and must not copy override wording into code. See [07](07-production-implementation-plan.md).
- **1.2 Community structure** — a category holds topics directly and
  subcategories; a subcategory holds topics. Don't add restrictions that aren't needed.
- **1.3 Native behaviour** — homepage route, topic ordering, category
  permissions, trust levels, signup, approval, posting permissions,
  notifications, tags, bookmarks, moderation, category moderators, anti-spam,
  uploads, rate limits, search.
- **1.4 Remove complexity** — disable or hide what Fomio doesn't need to
  emphasise. Product cleanup, not redesign.

### Phase 2 — The main-screen framework

The most important design phase. One reusable structure that carries
context, navigation, content and actions — with **no sidebar**:

```
┌───────────────────────────────────────┐
│ Global header                         │
├───────────────────────────────────────┤
│ Context                               │
│ Title / identity / metadata / actions │
├───────────────────────────────────────┤
│ Local navigation                      │
│ Tabs / filters / menus                │
├───────────────────────────────────────┤
│ Main content                          │
└───────────────────────────────────────┘
```

- **2A Global header** — intentionally boring. Fomio · Search · + ·
  Activity · Me. Utility, not information architecture.
  On mobile the header drops to logo and search; a **bottom bar** — Home ·
  Discover · Create · Notifications · Me — replaces core's hamburger drawer
  and the header avatar (05, Q2). Built with core's labels: Home (`/latest`)
  · Categories · New Topic · Notifications · Profile.
- **2B Context header** — one system for title, subtitle, community identity,
  breadcrumbs, description, statistics, follow/join, overflow actions and
  status. The same grammar for a category, a subcategory and a profile.
- **2C Context navigation** — the main screen owns tabs, sorting, filters,
  local menus and secondary actions. This is what replaces sidebar hierarchy.
  Category: Overview · Hot · Latest · About. Profile: Overview · Topics ·
  Replies · Activity. Search: All · Topics · Categories · People.
- **2D Main content** — shared treatments for feeds, lists, streams, grids,
  empty, loading, error and pagination, so Home, category, Search and Profile
  don't each invent their own.
- **2E Responsive** — the same architecture everywhere; mobile only changes
  density (compact, horizontal tabs).

### Phase 3 — The core journey

```
Home → discover community → category / subcategory → open topic → read → join → reply / post → return
```

Every Phase 3 screen must support this loop.

- **3A Home** — a feed of topic cards, not a forum table (cards supersede the
  old list decision, 2026-09-26). Tabs: tracked feed (`?f=tracked`) · Hot ·
  Latest.
  **Cards are lightweight discovery previews** (decided 2026-09-27): they
  help a visitor choose a topic and open it; acting on a topic happens on the
  topic screen. They are Discourse's official `discourse-topic-cards`
  component, not theme code, and keep what it renders natively: thumbnail,
  title, excerpt, author, likes, replies and age (with core's category link).
  **No Save/bookmark or share action on cards** — those stay on the native
  topic screen (3D). **Likes are the one card action**, an accepted
  exception (2026-09-27). Cards appear on every native topic list (Home,
  category, subcategory, suggested) on purpose. Native data, no
  recommendation engine.
- **3B Category** — a place, not a filter: context header, tabs,
  subcategories, hot topics.
  Subcategories are core's own list (category settings), shown as one row
  of links; a category opens on Latest, with Hot one tab away (decided
  2026-09-27).
- **3C Subcategory** — the category's design with a breadcrumb. No separate
  system.
- **3D Topic** — stay close to native. Redesign title hierarchy, metadata,
  spacing, actions, replies, avatars, status and topic context. Keep the
  topic stream; no nested-thread rewrite. Save (bookmark) and share live
  here, as core's native topic and post actions — not on 3A cards.
  **The topic stream is core's nested view** (`nested_replies_default` on,
  decided 2026-09-27): native, not a rewrite. 3D is settings only — the
  design fonts, and Save shown on every post.
- **3E Composer** — simplify the native composer: title, body, category,
  Post. Advanced features stay reachable.
  Done 2026-09-27: core's rich text editor (a setting) gives title,
  category, body and Create Topic with advanced features under Options; the
  theme aligns the docked composer with the column and the bottom bar's New
  Topic starts in the page's category.

### Phase 4 — Discovery and activation

- **4.1** Logged-out browsing: browse, enter categories, read topics without a wall.
- **4.2** Simple signup.
- **4.3** No interest-selection step for launch. Members choose categories
  through native controls and build their own tracked feeds after signup.
- **4.4** No personalized community suggestions for launch; use the native
  Categories directory for self-service discovery.
- **4.5** No bare "Nothing here" — fall back to popular categories,
  active discussions, suggested communities, latest topics.
- **4.6** Launch discovery uses native Categories, Hot and Latest surfaces;
  no separate Explore screen or unsupported popularity/growth metrics.

### Phase 5 — Supporting surfaces

They must work; they don't define the product.

| Surface | Treatment |
|---|---|
| Notifications | Light theme |
| Search | Native, with visual consistency |
| Profile | The main-screen framework; don't rewrite profile architecture |
| Bookmarks | Themed cleaner |
| Messages | Native PMs, light redesign |
| Preferences | Mostly native — not launch-critical |
| Moderation, Admin | Native |

### Launch gate

After Phase 5 we stop and test exactly this:

```
Visitor arrives → understands Fomio → sees useful content → finds a category
→ opens a topic → reads discussion → creates account → watches a category
→ replies or posts → gets notification → returns
```

If it works, launch — even if Preferences, admin or messages look like
Discourse, and even without a sidebar.

### After launch

- **6 Observe and repair.** Watch visitor → signup, signup → first watched category,
  first reply, first topic, topics → replies, D1/D7/D30 retention. Fix real
  friction: traffic without signups is onboarding; signups without follows is
  discovery; reading without participating is composer/community; users
  getting lost is navigation.
- **7 Navigation, only if earned.** If usage shows a persistent-navigation
  problem, a sidebar (Home, Explore, your categories, Bookmarks, Messages) comes back
  as a supplement. The main screen stays fully capable without it.
- **8 Differentiate.** Knowledge, wikis, collections, events, governance,
  reputation, community identity, moderator and creator tools,
  personalisation. Post-market work.
- **9 Native app.** The mobile app implements the proven model. Audit the
  existing mobile work screen by screen: keep, adapt, rewrite, remove.

## Status

| Phase | State |
|---|---|
| 0 | Locked 2026-09-26 |
| 1 | Settings applied 2026-09-26 ([05](05-phase-1-configuration.md)); existing text overrides intentionally remain unchanged |
| 2 | 2A mobile bar verified by user, then checked signed in on theme 36 with five fixes (composer hiding, minimized draft, label alignment, truncation, `aria-current`); device-only checks open; 2E done (mobile tab row instead of core's dropdown, user's decision); 2B category/subcategory context rendered on parent, subcategory, and no-description routes in preview 36 (logo case source-checked only); shell variables for 2C/2D are in. 2C Tracked filter built and verified signed in (Hot/Top ignore it in core — open). 2D states traced to core and checked; one empty-state fix. Re-baselined against Unified New 2026-09-27 (on for the site; compatible, no code change; 02, 07). 2B topic/profile done 2026-09-27 (same 840px column, core markup). Phone empty state clears the bar. Open: Tracked on Hot/Top (decision) and external device checks (safe-area, iOS PWA, touch swipe, RTL; 07). Plan in [07](07-production-implementation-plan.md) |
| 3 | **3B categories page (2026-09-27):** `desktop_category_page_style` back to core's `categories_and_latest_topics` (user's decision, mockup 02 Categories); native layout, no theme change; column width vs mockup open (07). **3A signed off 2026-09-27.** Cards come from the official `discourse-topic-cards` component (theme 37, attached to theme 36; the default switched between 31 and 36 that day; check before assuming which is live). Every acceptance criterion passes: signed in and signed out, desktop and 375px, Fomio light and Fomio AMOLED (now theme 36's dark palette), Tracked on, keyboard focus. Accepted exceptions: likes are the one card action; cards on every native list (Home, category, subcategory, suggested); theme 37 stays the upstream component until a Fomio fork. Results in [07](07-production-implementation-plan.md). **3B started 2026-09-27:** core's subcategory list turned on for the three parents with subcategories (category settings, rows) and restyled as a compact row of links; categories keep opening on Latest; the weekly activity count is deferred. Checked signed in and signed out, desktop and 375px, light and AMOLED. **3B closed 2026-09-27** after an accessibility smoke test: the topics column head is hidden, member new/unread badges stay, the notification level stays in core's nav row (07). **3C done 2026-09-27, native:** the subcategory page reuses the category design; parent and siblings stay in core's breadcrumb dropdowns (no parent link, no sibling row — user's decisions); verified signed in and out, both widths, both palettes, keyboard. **3D done 2026-09-27 with settings, no theme code:** nested view kept, fonts set (Source Sans Pro / Roboto Slab), bookmark shown on every post; verified signed in and out, both widths and palettes, on a staff-only test thread (07). **3E done 2026-09-27:** native rich-text composer; the docked composer aligned with the column; the bar's New Topic uses the page's category. **Phase 3 audit 2026-09-27:** 3A–3E pass signed in and out, both widths and palettes, 0 console errors; a real reply submitted through the composer (staff-only test topic, since soft-deleted). **Phase 3 signed off 2026-09-27** (07) |
| 4 | **Started 2026-09-30.** 4.5: visitor empty list built (core's empty state for signed-out visitors, ways out to Latest, Categories and Hot), verified signed out and in on theme 36. It was uploaded while theme 36 was the site default; the user has since restored theme 31, leaving the change on the preview. 4.1/4.2 read-only checks partial. **Decision (2026-09-30):** no interest picker or admin-set category defaults; members build their own tracked feeds. Native `/categories`, `/hot`, `/latest` are sufficient for launch discovery; no separate Explore screen or personalized community suggestions. Remaining Phase 4 items are in [07](07-production-implementation-plan.md) |
| 5–9 | Not started |
