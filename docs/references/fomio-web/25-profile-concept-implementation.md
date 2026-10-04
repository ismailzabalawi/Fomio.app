# Profile concept — 2026-10-01

User requested implementing the member profile concept. Supplied reference
`mockups/07 Profile.dc.html` depicts another member's Activity page. The
currently open route was own-profile `/u/soma/summary`; shared header and
navigation styles apply across profiles, with Activity stream typography
following the concept. Summary retains core's stats and content sections.

CSS only, scoped to `section.user-main`:

- Avatar 112px desktop, 72px below md; heading 32px / 24px.
- Identity spacing, secondary name, bio typography and native controls.
- Primary navigation has underlined active tabs; mobile retains named tabs
  with native horizontal overflow rather than core's icon-only presentation.
- Activity titles use heading typography; excerpts and rows match the
  concept spacing. Native dates, categories, images/excerpt placeholders,
  expand controls and post links stay intact.
- Summary section headings use the heading font and ordinary capitalization.

Native collapse/expand retained; bio and extended metadata are shown through
core's Expand action. No new follower counts, invented fields or Message
button: permissions and own/other-member actions remain core-owned. Core
background uploads and profile status/flair remain. Group pages are excluded.

Mapping checked against core `7b4f0970`: templates/user.gjs, base/user.scss,
base/new-user.scss, components/navs.scss, horizontal-overflow-nav.scss,
user-stream-item.scss, and the actual preview DOM. The active layout uses
`user-navigation-primary` / `user-navigation-secondary` from new-user.scss,
not the older `user-primary-navigation` layout in user.scss.

QA: theme 36 own Summary and Activity at 1280×900 and 390×844; native
Summary → Activity navigation, desktop and phone Expand, phone Collapse,
mobile visible tab labels, 112px/72px avatars, no horizontal page overflow
in collapsed or expanded states, no console errors/warnings. All four
repository guards pass. Other-member, signed-out, dark palette, cover image
and Message permissions not exercised. Theme 31 stays default; no commit/push.

## Tablet spacing follow-up

User requested fixing tablet spacing. Extended compact profile sizing and
named primary tabs to widths below lg (1024px); previously they stopped at
md (768px), leaving a 112px avatar and icon-only tabs on tablets. Added
12px inner gutters, allowed the identity row to wrap, and placed account
controls in a full-width row without core's desktop width cap or margins.
Verified Notifications at 834×1112, 768×1024, the 1024×768 desktop boundary,
and 390×844: no horizontal page overflow, 72px tablet avatar, readable tab
labels, and controls inside the content column. All four guards pass.
