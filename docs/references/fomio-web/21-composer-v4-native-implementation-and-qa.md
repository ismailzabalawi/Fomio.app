# 21 — Composer v4 native implementation and QA

2026-09-30. Local implementation and integration verification; **not a
completed v4 release or a deployment approval**. Continues [20](20-composer-v4-implementation-start.md).

## Direction and boundary

The user requested continuing until the project is finished. The active
scope remains the final composer, with docs 17–19's exclusions. The user
additionally accepted native formatting-menu behavior: on phones Discourse
closes the software keyboard before opening the menu. Do not implement the
prototype's keyboard-open formatting tray. Actual physical-keyboard/IME
testing is still required; accepting the behavior is not device evidence.

The category-first/bottom-toolbar shell was exercised locally with core's
`enable_composer_redesign`. At pinned commit `7b4f0970506fb0ce7d4b6a851d252ace418330c8`
this setting is **hidden, experimental, and conceptual**, not a stable
deployment prerequisite. The user explicitly chose **“Use the newer layout”** on 2026-09-30.
This is the selected build baseline; its experimental status remains a
release consideration. The theme does not enable it. Its additional shell
styles are scoped to core's `.uc-enable-composer-redesign` body class;
the stable layout retains functioning native controls and is also tested.

No production settings, posts, drafts, uploads, commits, or pushes were
made. All write-path verification used a disposable local account/database.

## Implemented

- `fomio-composer.js` replaces the opt-in preview initializer. The grouped
  Format control now loads with the theme, using the already-tested native
  command adapter. The old preview query parameter is no longer required.
- Native title typography, 44px toolbar/action targets, 840px centered
  desktop dock, theme-token spacing, and a title separator/focus indicator.
  The native resize/fullscreen/preview logic remains in charge of height.
- On the newer native layout: open writing surface, category before title,
  bottom toolbar, and the existing primary action moved into the phone header
  with CSS grid. No duplicate submit control or replacement submit handler. Existing Upload
  and Options titles are displayed as labels via `content: attr(title)`;
  copy stays translated by core. Emoji, mode switching, plugin tools and
  native toolbar overflow are retained.
- Offline warning and mobile native status text from [20], plus a focused
  phone-editor correction: core's field-sliding animation cannot move fields
  behind the editor. The fields scroll when long feedback or large text
  consumes the screen; the writing area retains a minimum 8rem height. The deferred close safeguard
  remains unimplemented, as explicitly requested by the user.
- Public/Private category subtitle reads the native selected category
  `read_restricted` value through `after-composer-category-input`. Missing
  access data produces no label; there is no inferred permission state.
- Category filtering keeps its native input and adds the approved accessible
  name. No editor, parsing, draft store, upload queue or request was replaced.
- Full-suite testing exposed an existing Tracked navigation listener that
  outlived its router. It now removes the listener using the router's Ember
  destructor. This is a small lifecycle fix, not a navigation redesign.

## Real local runtime

An isolated source export at the pinned commit was provisioned at
`/tmp/fomio-composer-dev`, with runtime configuration in
`/tmp/fomio-composer-dev-runtime`. It uses Node 24, Ruby 3.4.7, Bundler 4,
the pinned package locks, PostgreSQL on a private socket/port 15432 and Redis
on loopback port 16379. Rails listens only on loopback port 4300. Existing
user database services and the original Discourse checkout were untouched.

Local URL: `http://localhost:4300`. Theme id 1 imports this working tree.
Outgoing email is disabled. Synthetic account: `composer_test`.
The theme is compiled by the real Discourse frontend/Rails pipeline,
including its GJS template and native outlet. No static fixture substitutes
for these integration checks. The temporary installation is a review/test
environment, not a production deployment or a durable hosting arrangement.

## Executed evidence

| Check | Result |
|---|---|
| Composer QUnit suite | **20 tests, 104 assertions, zero failures** (earlier composer subset; the later audience test adds five assertions), through `/theme-qunit?id=1&filter=Fomio%20%7C%20Composer` |
| Coverage | Mobile/desktop service modes × legacy/redesigned layouts; actual failed native draft-save request and recovery in both rich/Markdown modes; conflict text; category filter; selected-word formatting; Markdown/rich round-trip; same model/body after native minimize/resume; one Format control |
| Native Toolbar adapter tests | **7/7 passed** against the actual pinned core Toolbar source (host-only dependencies stubbed; not a browser substitute) |
| Local browser create/edit/reply | Native UI successfully created topic 7, edited its first post, and added a reply. Final rendered bodies and destination were inspected. All content was synthetic. |
| Offline browser check | Blocked local `/drafts.json`; native `drafts offline` and the added warning appeared while rich-editor writing remained intact. At 390×844 the warning occupied y=77…219, and the editor began at y=366: no concealment behind the focused editor. |
| Browser reconnect limit | A later native save returned 409 and displayed `draft error`; do not claim this browser run proved successful draft recovery. Recovery is covered by the request-controlled QUnit tests. Clearing network simulation allowed the subsequent local publication. |
| Resize continuity | 375×667, 600×834, 834×1194, 1194×834 and 1280×800: unchanged body, exactly one Format and one Upload control, zero document horizontal overflow. These are browser emulation, not physical device rotation/keyboard proof. |
| Native resize | Native drag handle produced the reference desktop shell bounds x=220, y=248, width=840, height=552 in a 1280×800 viewport. No theme-owned height store was added. |

The first full-theme run exposed two Tracked-filter failures from the stale
router listener described above. After its cleanup fix, the **full theme
suite passed: 33 tests, 152 assertions, zero failures**. All four repository
guards passed against the pinned source, and `git diff --check` passed.

## Fidelity ledger and unfinished work

Compared native browser captures using `view_image` with the frozen r1 S01
phone, S38 desktop and S41 warning reference. The accepted ZIP/reference
remains unchanged. This review **does not pass final fidelity sign-off**.

| Point inspected | Current result / remaining difference |
|---|---|
| Surface and palette | Native secondary/primary/tertiary tokens; no invented color literals. Local defaults can differ from live site overrides. Fomio light and Fomio AMOLED native palettes inspected in the local site. |
| Desktop dimensions | 840px dock confirmed; native resizer reaches the 552px reference height. Initial/persisted native height is not forcibly replaced. |
| Typography | Site heading font and 24px-range title scale; native body typography. Title border/focus is visible. |
| Hierarchy and spacing | Newer core layout provides category → title → writing → toolbar. The current stable layout still has its original field/toolbar order. |
| Copy above the fold | Native title/body placeholders retained. Intentional approved differences: Upload instead of Photo, Options instead of More, Strong/Emphasis instead of Bold/Italic. No global terminology overrides. |
| Phone action placement | Primary action is now in the header at phone widths. Native Discard, intent row, close/minimize, mode and emoji controls remain available; these are visible differences from the simplified reference chrome. |
| Category audience | Native chooser retained; Public/Private subtitle is implemented from core category data, with a test covering public, restricted and unknown access. |
| Formatting panel | Native menu, commands, selection and shortcuts; keyboard closing accepted by user. Not the prototype's tray geometry. |
| Warning | User-approved copy replaces the prototype's blocked-close actions. The later safeguard remains deferred. |

## Final local visual and interaction pass

The earlier incorrectly scaled captures were discarded. Applying viewport
sizes to the selected local test tab produced reliable captures, inspected
with `view_image`. The local site header/onboarding content is test setup,
not a replacement for the production homepage.

| Evidence | Result |
|---|---|
| [Phone light](composer-v4-implementation/phone-light.png), 390×844 | Header action, category/audience, serif title and bottom toolbar. Upload, Format, emoji and Options fit at normal text size alongside the native mode switch. |
| [Phone dark](composer-v4-implementation/phone-dark.png) and [desktop dark](composer-v4-implementation/desktop-dark.png) | Native Fomio AMOLED palette, same controls and writing hierarchy. |
| [Desktop light](composer-v4-implementation/desktop-light.png), 1280×800 | Centered 840px native dock, native initial height 400px. Height remains user-resizable. |
| [Tablet light](composer-v4-implementation/tablet-light.png), 834×1194 | Native dock at 802px width, no document horizontal overflow; existing draft text retained across resizing. D1's tablet customization remains deferred. |
| [Largest text](composer-v4-implementation/phone-largest-text.png), 360×740 | Native 20px root font. Actions wrap without document overflow; toolbar labels no longer overlap. Native horizontal toolbar scrolling reaches Options. The single-line native title scrolls horizontally for long titles. |
| [Arabic dark](composer-v4-implementation/phone-rtl-dark.png), 360×740 | Real native Arabic locale, RTL direction, mirrored header and category, zero document overflow. Theme-only Format copy currently falls back to English; full localization is not claimed. |
| [Large offline warning](composer-v4-implementation/phone-offline-largest.png) and [writing after scrolling](composer-v4-implementation/phone-offline-largest-writing.png) | Actual blocked local draft-save request; warning remains readable. At 360×740/20px text the editor retains 160px height, and the field region scrolls by 131px to expose writing. Network blocking was cleared afterward. |
| Upload and content blocks | A generated 96×96 test image uploaded through the native picker, rendered, resized to 75%, survived rich/Markdown switching and draft reload. Native Table Builder, Hide details, Blur spoiler and Build poll inserted their native markup. Correctly separated blocks rendered as a table, details, spoiler and poll in rich text. |
| Plugin runtime | The isolated source export required `assets:precompile:build_plugins`; after compilation, native details, footnote, local date/time, spoiler and poll options appeared. No plugin functionality was reimplemented in the theme. |

The first chained insertion exercise placed table markup directly after an
image and a poll inside a selected spoiler, producing literal markup in rich
text. Separating those blocks rendered correctly. This is not proof that
arbitrary nested content works; native insertion/parsing remains authoritative.
The local offline-to-online check again encountered core's draft-conflict
error. Successful recovery is covered only by the controlled native request
tests, not by that browser sequence. No safeguard against offline close is
claimed or implemented.

The native overflow arrow has no accessible name at this pinned core
version. Its buttons remain individually named, but a physical screen-reader
pass is outstanding. No upstream accessibility sign-off is implied by our
category-search or live-status tests.

## Review archive verification

The final ZIP contains 13 runtime files (22,745 bytes), with byte-for-byte
source checks and hashes in its manifest. `RemoteTheme.update_zipped_theme`
imported it into local theme 1 successfully: `supported: true`, no validation
errors. The final full native suite passed 33 tests / 152 assertions, and all
four repository guards plus `git diff --check` passed. No commit or push was
made. Temporary browser network blocking and viewport overrides were reset;
the disposable account returned to normal text, default locale and automatic
color mode.

## Review candidate and remaining gates

Local theme implementation and browser QA are ready for review. This is not
final cross-device or production sign-off. The user selected the newer
layout; the hidden `enable_composer_redesign` setting must be evaluated on a
separate test site before any site-wide change. A theme preview URL does not
isolate site settings.

The minimum version metadata now matches the tested core generation,
`2026.8.0.beta0` as a coarse floor; core's metadata validator rejects
`-latest` even though the running version uses that suffix. The previous
3.4 floor did not cover the current native composer APIs. The exact tested commit remains the compatibility reference;
newer core revisions must be rechecked.

Remaining release gates:

1. Physical iPhone/Android software keyboard, selection/IME, rotation and
   tablet split-screen checks, including long warnings and large text.
2. VoiceOver/TalkBack and keyboard-only review, including native toolbar
   overflow, focus after menus and visible/DOM action order.
3. Site-specific conditional controls: PM, whisper/staff/shared drafts and
   installed plugin combinations. Preserve their native availability; the
   phone header grid explicitly excludes private messages.
4. Review the visible native-control differences above, real draft-conflict
   recovery and the accepted offline-close risk. D8 guided forms and the
   other deferred product decisions remain out of scope.
5. User-operated staging installation/review and a rollback rehearsal before
   any separately authorized live rollout. No production write is authorized.

See [22 — Composer review handoff](22-composer-v4-review-handoff.md) for the
plain-language next steps, review archive and version boundary. Do not mark
these remaining gates as passed based on browser emulation alone.
