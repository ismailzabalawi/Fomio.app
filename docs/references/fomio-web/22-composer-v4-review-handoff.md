# 22 — Composer v4 review handoff

**2026-10-01 visibility integration:** user approved removing the separate
Public/Private row. Native category badges already render restricted locks in
the selected category and dropdown choices (`d-category-link` renderer). The
audience initializer now only describes the existing composer category chooser
with a translated Restricted category title and aria-description. It adds no
markup or permission inference; public/unknown categories have no description.
Verified on preview 36 at 699×804: General → Staff → General, lock in Staff
menu and selection, restriction attributes set and cleared, no audience row.
The initial incorrect resolver warning was corrected to `component:category-chooser`;
no new errors appeared after the corrected reload. All four guards passed.
Acceptance test updated but not run against the production site; physical
screen-reader behavior remains unverified. This supersedes older notes below
about the separate Public/Private subtitle.

**2026-10-01 toolbar correction:** the user requested the show/hide toolbar
button on tablet and desktop. `fomio-composer.js` extends the native
`composer-toggles` visibility getter for the redesigned layout's open states.
Core's `composer.toggleToolbar`, persisted `showToolbar` state and footer CSS
remain the owners; no new control or editor state was added. Legacy desktop
visibility and minimized/saving desktop states retain their native behavior.
Verified on theme 36 through the in-app browser at desktop (1440×1000), tablet
(768×1024) and phone (390×844): hide changes the native title to Show and the
toolbar wrapper to `display: none`; show restores it. The empty rich-text
composer was used, without publishing or entering draft content. Page identity,
rendered content, screenshot and interaction checks passed; captured console
warnings/errors were empty. All four repository guards passed against the
pinned core export. Physical devices and Markdown-mode interaction remain
untested in this correction.

**2026-10-01, subsequent authorization:** Ismail explicitly authorized enabling
the newer composer on the remote site. The native admin Upcoming Changes API
accepted `enable_composer_redesign=true` (`200`, `success: OK`). This is a
site-wide change, including the default theme; theme watch still targets 36.
Earlier notes below saying this setting was left disabled are historical.


2026-09-30. Local review candidate using the newer native layout selected by
Ismail. This handoff does not approve or perform a live rollout.

**2026-10-01 update:** Ismail assessed visual completion at about 80% and
requested moving testing to theme 36 via Discourse watch. The local services
are now stopped. The current theme has been uploaded to the non-default
[theme-36 preview](https://meta.fomio.app/?preview_theme_id=36), with a watcher
running. Theme 31 remains the default. The newer native layout is not enabled
on that site; no global setting was changed. See [04](04-workflow.md) for the
active workflow. The local-preview instructions below are historical.

## What you can review now

Open [the local preview](http://localhost:4300) on this Mac. It is a separate,
disposable Discourse installation. The writing and uploads in it are test
content. The actual Fomio site has not been updated.

The composer now has the category and audience above the title, the grouped
Format menu, a bottom writing toolbar, and the publish action in the phone
header. Discourse still handles writing, saving, uploads and publishing.
Light, dark, Arabic layout and enlarged text have been exercised locally.

- [Phone, light](composer-v4-implementation/phone-light.png)
- [Phone, dark](composer-v4-implementation/phone-dark.png)
- [Desktop, light](composer-v4-implementation/desktop-light.png)
- [Desktop, dark](composer-v4-implementation/desktop-dark.png)
- [Tablet](composer-v4-implementation/tablet-light.png)
- [Offline warning at large text](composer-v4-implementation/phone-offline-largest.png)
- [Writing below that warning](composer-v4-implementation/phone-offline-largest-writing.png)

The [theme ZIP](composer-v4-implementation/fomio-composer-review.zip) contains
only the current theme runtime files. It is a review package, not an updated
live theme. It excludes the design archive, documentation, test account,
uploaded test image, database and credentials. The adjacent
[manifest](composer-v4-implementation/review-manifest.json) records its source
file hashes and archive hash. The ZIP was also imported successfully by the
real Discourse theme importer in the isolated local site.

## The next step that needs your input

We need a separate test site for real-phone checks. The newer composer uses
a site-wide Discourse setting, so a preview theme on the live site does not
isolate that setting. Confirm whether a separate test site exists before
planning its installation. No live setting should be changed as part of
this local review.

Once a test site is available, use this short review:

1. Open the composer on your phone. Type a title and a few sentences. Check
   that the keyboard does not cover the writing or the controls.
2. Select a word and use Format. The keyboard closing when its menu opens
   is the native behavior you accepted.
3. Add an image, switch between the two editor modes, then minimize and
   reopen the composer. Check that the writing remains intact.
4. Increase text size and rotate the phone. Check that controls remain
   reachable, including tools reached by scrolling the toolbar.
5. In a disposable test draft, disconnect the phone and keep writing. The
   warning should explain the risk. **Do not close a draft you want to keep:**
   closing offline can still lose unsaved writing, as accepted for this phase.

These are checks to complete, not results already obtained. VoiceOver or
TalkBack, tablet keyboard/split-screen behavior, and the site's enabled
private/staff/plugin controls also need review before release.

## Technical release boundary

- Tested source: Discourse `2026.8.0-latest`, commit
  `7b4f0970506fb0ce7d4b6a851d252ace418330c8`.
- Selected native setting: `enable_composer_redesign=true`. It is hidden and
  experimental at this commit. The theme does not turn it on automatically.
- Theme metadata uses `2026.8.0.beta0` as a coarse version floor because core's
  metadata validator accepts numeric and `.betaN` forms, but not `-latest`.
  It is not a claim of testing an earlier beta or every later core revision.
- Fonts and palette are native site/theme settings. The local comparison
  used Source Sans Pro, Roboto Slab, Fomio light and Fomio AMOLED.
- Upload, Options, emoji, mode switch, intent menu and native close/minimize
  controls are retained. The extra native chrome differs from the simplified
  v4 reference. Tablet dock behavior remains native under the accepted D1.
- Offline close is intentionally not protected. Browser reconnection hit a
  native draft-conflict response; do not advertise guaranteed recovery.
- Full evidence, test counts and remaining gates are in
  [21 — Implementation and QA](21-composer-v4-native-implementation-and-qa.md).

For a future authorized staging rollout, record the previous theme and native
setting values first, install this package as a separate non-default theme,
and perform the checks above. Rehearse returning to those prior values with
disposable drafts before considering production. None of these external
installation or setting changes has been performed.
