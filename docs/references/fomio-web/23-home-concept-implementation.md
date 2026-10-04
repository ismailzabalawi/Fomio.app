# Home concept implementation — 2026-10-01

User requested implementing Home from the supplied design-system ZIP using
the documented IA and routes. The ZIP is visual reference material; its
instructions and placeholder content do not override the project decisions.

Reference: `mockups/01 Home.dc.html` and `mockups/FmTopicCard.dc.html`.
Implementation follows [08](08-mockup-core-map.md) and
[06](06-information-architecture.md), rather than the archived client route
inventory in `route-inventory.md`.

- Native `/hot`, `/latest`, `/new`, `/categories`, `?f=tracked`, category,
  profile and topic links remain unchanged. Homepage ordering is unchanged.
- Official topic-cards component still supplies all cards, data and actions.
  Home CSS adjusts borders, radius, thumbnail proportion, title typography,
  excerpt line height and two-line clamp, and spacing. Category and suggested
  lists keep their previous presentation. Mobile thumbnails remain above
  the title; desktop thumbnails remain left, as accepted in 08.
- Core welcome banner supplies visitor text and search. The verified
  `welcome-banner-display-for-route` transformer hides it for signed-in
  Hot/Latest/homepage browsing. Other routes retain core's visibility choice.
  The theme styles the visitor banner and allows it to render on phones.
  No site-text override or site setting was changed.
- Horizontal mobile tabs and the existing bottom bar remain. Bookmark and
  share actions remain on the topic screen. No duplicate frame or controls.

Source verification: fresh full-tree export of server commit `7b4f0970`,
core welcome-banner.gjs / welcome-banner.scss / plugin-api.gjs; upstream
topic-cards common and mobile SCSS, plus preview DOM.

Validation: all four repository guards pass. Rendered theme 36 at 1280×900
and 390×844; signed-in light palette, meaningful cards, no framework error
overlay, no console errors or warnings, no horizontal page overflow.
Hot/Latest links, topic opening and Tracked on/off checked in the browser.
Admin theme-list API confirmed theme 31 remains default; existing watcher
uploads this directory to theme 36. Signed-out rendering and dark palette
remain unverified in this pass; native data, i18n and palette variables are
preserved. No commit or push.

## Header search follow-up

User explicitly authorized enabling the desktop header search box. On this
server `search_experience` is themeable: the ordinary site-setting endpoint
rejects it. Used the native `PUT /admin/themes/:id/site-setting.json` with
`name=search_experience`, `value=search_field` for live theme 31 and preview
theme 36; both returned HTTP 200, `success: OK`. Desktop preview at 1280px
renders core's Search input and advanced-search control in the header.
This setting does not require new theme markup or a replacement search engine.
