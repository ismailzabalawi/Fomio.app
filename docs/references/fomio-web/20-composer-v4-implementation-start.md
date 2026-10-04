# 20 — Composer v4 implementation start

2026-09-30. **Local implementation started; not deployed, not release-ready.**

**Continuation:** [21 — native implementation and QA](21-composer-v4-native-implementation-and-qa.md) supersedes the unexecuted-test status and missing-development-site blocker below. This document preserves the first-slice record.

## User direction

The user explicitly requested starting implementation, using the existing
roadmaps and frontend-app-builder skill, with no actions on their behalf.
Work is local: no commit, push, upload, site-setting change, live draft or post.
They subsequently chose **“Use the existing v4 design”**, opting out of new
Image Gen concepting. All five main composer files in the supplied ZIP are
byte-identical to the frozen r1 files: review, prototype, handoff,
`FmComposer4.dc.html`, and `fmc4-lib.js`. Use that visual reference together
with docs 17–19's native behavior dispositions, not every simulated action.

For D4 the user explicitly directed: **“keep the current behaviour, add an
alert to users, and we will safeguard later. document it nevertheless.”**
This resolves the product choice raised in doc 19 for this slice. It does
not establish that native close is safe, and does not authorize a new close
guard, retry flow, clipboard action or persistence layer.

## First implementation slice

Scope: Stage 1's LT/P-4 remedies and the user-directed D4 warning. The
responsive shell and subsequent roadmap stages are not complete.

| Change | Native trace and ownership |
|---|---|
| Visible offline warning | `models/composer.js:1594` sets `draftStatus` to translated `composer.drafts_offline` after an otherwise unclassified draft-save failure. The new component reads that model property with Ember `get`, and shows an additional warning only for that exact translated status. It does not infer persistence from browser connectivity or toast text. |
| Mobile error/status text | Read the same native `draftStatus` in `before-composer-fields`. Both native composer layouts pass `model` to this outlet (`components/composer-container.gjs:472`). Desktop keeps its existing generic status presentation; the offline warning appears on all devices. Native footer icons, conflict avatar and upload progress remain. |
| Category-search accessible name | The native `select-kit/select-kit-filter.gjs:154` Input has a placeholder but no accessible-label argument. `api.modifyClass` extends its existing `didRender` lifecycle, setting `aria-label` only inside `#reply-control .category-chooser`. It preserves the native Input, event handlers, placeholder and any `aria-labelledby`. No component template is replaced. This targeted DOM-attribute adaptation needs native runtime verification and upgrade review. |

Sources above were read in `/tmp/discourse-7b4f0970`, matching the last
observed server commit. No fresh live-server version claim is made.

The draft component uses the field outlet so the redesigned composer's
existing `trackFieldsHeight` measurement includes the warning. It never
writes the model, editor selection, body, category, draft sequence or upload
queue. New/reply/edit all pass the same model; native intent and outcome
handling are untouched. No request originates from either new initializer.

Two scoped translations are justified:

- `composer.unsaved_close_warning`: the user-requested warning, absent in
  the native offline-close path: “Your latest changes have not been saved.
  Closing the composer may lose them. Keep it open until your connection
  returns and the draft saves.”
- `composer.search_categories`: “Search categories”, approved P-4 policy.

## Deferred safeguard / known risk

The live audit in doc 19 observed Save and close losing offline writing and
showing a misleading “Draft saved!” toast. **This patch does not fix either
behavior.** The new notice only appears after core reports a failed draft
save; closing before that status arrives can still lose writing without the
notice appearing. Native close may also remove the notice with the editor.

Future safeguard acceptance: retain recoverable writing until a save is
confirmed; distinguish failed save from confirmed save; require a deliberate
discard path; test races, reconnect, conflicts and both editor modes. This
is deferred, not an implemented guarantee. D3/D5–D10 keep doc 17's scope.

## Verification and limits

- Four repository guards passed: native values, core-variable names,
  SCSS compilation and duplication/outlet allowlist.
- Existing native-toolbar adapter suite: 7/7 passed against the pinned
  Toolbar. These are regression checks, not proof of the new feedback.
- Added 12 development-Discourse acceptance cases across mobile/desktop
  and legacy/redesigned composer: native status changes and recovery,
  conflict wording, no body/compose-state mutation, and category search.
  **Not executed:** no isolated running development Discourse was supplied.
  The new GJS component also awaits Discourse template compilation there.
  Production `meta.fomio.app` cannot run theme QUnit (doc 04).
- Browser/IAB inspected an isolated, clearly labelled visual fixture using
  the actual compiled feedback SCSS, native warning SVG and reference tokens.
  It was not an Ember renderer or a substitute for integration testing.
- Checked 390px and 834px component widths, 16px/24px text, a 1280×800
  browser viewport, and a 390×844 browser viewport. At the narrow viewport,
  preview page gutters left 342px for each component; measured horizontal
  overflow was zero. Native keyboard, rotation and true browser zoom remain
  unverified. Preview palette switching required direct navigation because
  IAB clicks did not update the fixture; no interaction-pass claim follows.
- Inspected the r1 S41 reference and light/dark fixture screenshots together
  with `view_image`. This is a **component review, not full composer fidelity
  sign-off**. Temporary preview files are not shipped as theme code.

Retained visual review outputs (local artifacts, not native integration proof):
[light preview](/Users/ismailzabalawi/.codex/visualizations/2026/09/30/01a0f377-c789-7f61-a8ec-50de5779a30f/composer-feedback-light.png),
[dark preview](/Users/ismailzabalawi/.codex/visualizations/2026/09/30/01a0f377-c789-7f61-a8ec-50de5779a30f/composer-feedback-dark.png).

### Fidelity ledger

| Comparison | Evidence / disposition |
|---|---|
| Copy | Native status retained; the added risk warning is intentional user-directed copy. The reference's Retry save / Keep editing buttons are excluded by D4. Complete composer above-the-fold copy diff remains pending. |
| Placement | Reference S41 warning precedes writing fields. The native `before-composer-fields` outlet targets the same hierarchy; native runtime placement remains unverified. |
| Typography | Uses site-owned font and size tokens, bold status and wrapping body. Fixture checked 16px and 24px; no fixed text height or truncation. |
| Palette | True-white light / true-black dark reference backgrounds; offline notice uses native `danger-low`, `danger` and `primary`. Initial neutral notice background was corrected to warning colors. Native palette derivation may differ from the reference's simulated color ramp. |
| Icon | Reuses core's filled warning triangle; the reference banner has a filled exclamation circle. Intentional native-icon reuse, consistent with retained native draft warning. |
| Container / spacing | Compact notice with existing radius/spacing tokens; differs from the reference's full-width recovery panel because custom recovery actions are deferred. This layout needs review in the real composer, especially short keyboard viewports. |
| Responsive | Fixture text wraps at normal/large sizes and narrow width; an overflow in the temporary fixture wrapper was fixed. This does not prove the native shell or keyboard layout. |

## Next gate

Use an isolated development Discourse at the pinned version to run the new
tests, verify scoped category labeling (including unrelated dropdowns), and
exercise warning appearance/removal in both editor modes and composer
layouts. Then continue Stage 1's remaining interactions before building the
full responsive shell. The user was asked whether a separate test site exists;
no live-site mutation is authorized by the present request.
