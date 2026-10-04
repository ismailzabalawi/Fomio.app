# 01 — Context and decisions

## What this is

Fomio's web surface, as a Discourse theme.

- **Product:** a Reddit alternative — many small communities with one feed
  across them.
- **Analogy the user gave:** be to Reddit what Telegram is to WhatsApp — open
  API, generous limits, power-user features, fast cadence, playful.
- **Backend:** `https://meta.fomio.app`, Discourse `2026.8.0-latest`, core
  commit `7b4f0970` (see 02).
- **Shape:** a theme on stock Discourse. Not a fork, not a headless client.
- **Repo:** `github.com/ismailzabalawi/fomio-web` (private), branch `main`.

## History

1. `~/Projects/Fomio/apps/web` — the first web theme. Built on the Expo app's
   values, which hardened into literals (150 `--fomio-*` properties, 114 hex
   literals). Reference only; don't work there.
2. This repo, first pass (2026-09-17 → 09-25, branch **`archive/v0`**). A
   clean-room theme with good guardrails, but it drifted into restyling the
   whole of Discourse: sidebar, settings rail, category header, list rows,
   preferences.
3. **Restart, 2026-09-26.** `main` reset to a skeleton; the roadmap in
   [00](00-roadmap.md) replaces the earlier four-phase design process.

## Phase 0 — locked decisions

- Discourse stays the backend and application core
- no separate custom web app
- no custom BFF for launch
- no replacement search, moderation, notifications or composer engine
- **no sidebar for v1** (`navigation_menu` = `header dropdown`, see 05). On
  mobile, a bottom bar replaces core's drawer and header avatar (05, Q2)
- no major mobile rebuild before launch
- no custom data model unless absolutely necessary

Plus the redesign rule and the priority ladder in 00.

## Standing rules from the user

1. **Native settings only.** Use what Discourse already offers — site
   settings, category settings, colour schemes, text customization, the
   standard theme `settings.yml`. Never a parallel settings layer.
2. **Build on the shoulders of others.** If a plugin or component already
   does it, adopt or extend it. Write only the glue and the genuinely new
   parts.
3. **Ask, don't conclude.** When direction is unclear, ask. An existing repo
   or artifact is context, not an instruction to reorganise around it.
4. **Commit and push only when asked.**

## Vocabulary

**Terminology source (updated 2026-09-26):** Discourse owns rendered product
text. The existing 69 site-text overrides remain active and unchanged for
now, per the user's later clarification; they are not to be reverted as part
of theme work. Theme code must use Discourse's i18n output and must not copy
override wording into templates, stylesheets, or JavaScript literals. See
[07 — Production implementation plan](07-production-implementation-plan.md).

An earlier decision below to drop all Hub / Teret / Byte wording is superseded
for the live site-text overrides. It still applies to hardcoded theme copy:
the theme must not introduce or duplicate product terminology.

## Code rules carried over from v0

These held up and still apply:

- **R1** No colour literals in stylesheets — palettes live in `about.json`.
- **R2** No font names in stylesheets — `base_font`, `heading_font` site
  settings.
- **R3** No new CSS custom properties — set and read core's.
- **R5** Set Discourse's variables before overriding its selectors.
- **R6** Dark mode comes from the palette.
- **R7** Breakpoints are Discourse's (`viewport.from(sm|md|lg|xl)`).
- Restyle what Discourse renders; never insert a design's own header, nav or
  frame beside it. New markup only in outlets allowlisted in
  `scripts/check-duplication.sh`.
- Confirm every variable, selector and transformer in core before writing
  it (02).

## Decisions carried over from v0

| Decision | Detail |
|---|---|
| Brand | **Changed 2026-09-26** to the design pack's palettes: "Fomio" (ink on white, violet `tertiary`) and "Fomio AMOLED" (true black) in `about.json`, editable in Admin → Colours. The terracotta Fomio / Fomio Dark palettes are retired |
| Fonts | **Changed 2026-09-26** to the design pack's: `base_font` Source Sans Pro (`source_sans_pro`), `heading_font` Roboto Slab (`roboto_slab`). Site settings; the theme never names a font. Replaces Lora / Raleway. **Set on the site 2026-09-27** (3D) |
| Topic stream | **Core's nested replies view** (`nested_replies_default` on), decided 2026-09-27 for 3D; supersedes "keep the flat stream for v1" (05 Q5) |
| Core plugins are bundled | Post-voting, topic-voting, reactions, solved, chat etc. are enabled by site setting, not installed |
| Dev loop | `discourse_theme watch .` against the live site, as non-default theme 36 (04) |

## Superseded by the restart

| Old | Now |
|---|---|
| Sidebar restyled as primary navigation | No sidebar for v1; the main screen carries navigation (Phase 2C). Revisit only in Phase 7 |
| Mobile hamburger drawer | A bottom bar, ported from the old theme; replaces the drawer and the header avatar on mobile (2026-09-26) |
| Feed as list rows | Topic cards (Phase 3A), **from the official `discourse-topic-cards` theme component** (decided by the user 2026-09-27), installed from git as theme 37 and attached to this theme as a child. No Fomio card code. **Scope (2026-09-27):** lightweight discovery previews — thumbnail, title, excerpt, author, likes, replies, age as the component renders them; no Save/bookmark or share on cards, which stay on the native topic screen (3D). **Audit decisions (2026-09-27):** likes/reactions are the one allowed card action; cards stay enabled on Home, category, subcategory and suggested-topic lists (intentional, for 3B/3C); theme 37 stays the upstream external component until a Fomio-owned fork (36 was briefly the site default on 2026-09-27; the site default switched between 31 and 36 more than once that day (36 again at the 3B check), so check `/admin/themes.json` before assuming 36 and 37 are live) |
| Hardcoded Hub / Teret / Byte vocabulary in theme code | Discourse-resolved wording; existing site-text overrides remain unchanged |
| Phase 1–3 design artifacts (route map, token schema, wireframes) | Input only. Where they assume a sidebar or list rows, the roadmap wins |
| Custom category header, settings rail, preferences restyle | Archived. Preferences stay mostly native (Phase 5) |
| Three theme settings (`corner_style`, `reading_width`, `list_density`) | Removed with the code; re-add one only when a Phase 2 need can't be met by a Discourse setting |

## Design reference

The Claude Design screen pack (project `10e05e50-…`, `mockups/00 Index.dc.html`)
is the visual reference for Phases 2–5, adopted 2026-09-26. It is a
reference, not a spec: each element ships only once it has a core source,
recorded in [08](08-mockup-core-map.md).

The v0 code on `archive/v0` is a quarry, not a base: lift a verified piece
only when a phase needs it, and re-verify it against core first.

## Open product questions

Parts of the roadmap that core doesn't back natively. Each needs a decision
before the phase that uses it — tracked at the end of 05.
