# 12 — Composer v4 implementation roadmap

**Latest direction, 2026-09-30:** the user has now requested implementation
using the existing v4 design. Local Stage 1 work has started; see
[21 — native implementation and QA](21-composer-v4-native-implementation-and-qa.md) for the
current scope, passing native tests and remaining gates. D4 now explicitly retains native close
behavior with an added warning; safeguarding unsaved writing is deferred.
Historical approval-status statements below describe earlier requests.

Prepared 2026-09-30. **Planning only; implementation has not been authorized by
this roadmap request.** The user likes the v4 direction and wants a faithful
translation into Discourse. Agreeing with the direction does not automatically
resolve every proposed behavior in the handoff.

**2026-09-30 alignment:** the user accepted this roadmap and requested that it
be linked with the IA and researched composer files for agents. This is the
adopted planning sequence. [13 — Agent guide](13-composer-agent-guide.md) is
the entry point and native reuse contract. D1–D10 remain explicitly pending;
neither this alignment nor the old prototype starts implementation. Stage 0
still records the immutable design snapshot and final outstanding choices.

**2026-09-30 decision update:** Ismail directed D1–D2 to a later settings
review, D3–D7 to native Discourse behavior, and D8–D10 to later consideration.
The exact scope and limits are recorded in [17 — decision update](17-composer-v4-decision-update.md).
The earlier pending statement above describes the state when this roadmap was
adopted; it is superseded for D1–D10 by that update.

## Reference and ownership

- [Current design review](https://claude.ai/design/p/10e05e50-973c-4ddb-836f-406e5456a4f2?file=mockups%2F06%20Composer.dc.html): v4, inspected for this roadmap.
- [Interactive prototype](https://claude.ai/design/p/10e05e50-973c-4ddb-836f-406e5456a4f2?file=mockups%2F06.1%20Composer%20Prototype.dc.html).
- [Design handoff](https://claude.ai/design/p/10e05e50-973c-4ddb-836f-406e5456a4f2?file=mockups%2F06%20Composer%20handoff.md): sections 4–10 define device rules, proposals, copy, decisions and feasibility gaps.
- [09 — Native research](09-composer-research.md) and [10 — IA](10-composer-ia-map.md): source and route evidence. Research was pinned to `7b4f0970`; re-check the server before implementation.
- [11 — Premature feasibility experiment](11-composer-native-feasibility.md): findings only, not the accepted UI or an implementation baseline. The user clarified that design must be locked first.

Discourse continues to own the editor document, rich/Markdown conversion,
selection commands, drafts/sequences, Uppy uploads, Onebox, native builders,
permissions, validation, moderation and publishing. Fomio owns the agreed
presentation and supported interaction adaptations. No core fork, block
editor, replacement parser, draft store or publishing API is in scope.

The mockup's simulator, fixtures, fixed safe-area values, summary cards and
synthetic network outcomes are design aids, never production code to copy.
Use real viewport/safe-area measurements and native rich-content rendering.
Existing site vocabulary, palettes and fonts remain governed by Discourse.

## Delivery sequence

Proceed in order. Each stage produces a small reviewable change and evidence;
never wait until the end to compare the implementation with the design.
No stage below is recorded as complete by this planning document.

| Stage | Deliverable and scope | Exit condition |
|---|---|---|
| 0. Lock the reference | Freeze v4 files/frame inventory, record D1–D10 decisions and deferrals, reconcile affected frames/copy, and record intentional exclusions | User approves the reference with documented deviations, then explicitly authorizes implementation |
| 1. Prove the difficult interactions | Confirm native extension points; test selection/keyboard panels, tablet transitions, upload presentation, draft recovery and proposed builders in an isolated development installation | Every risky behavior is supported by evidence or has a revised design agreed before dependent work |
| 2. Build the responsive shell | Context, title/body hierarchy, primary action, draft status, docked/fullscreen/minimized presentation, preview and bottom-nav interaction | New/reply/edit shells match phone, tablet and desktop references without replacing the editor or losing state on resize |
| 3. Build the writing experience | Photo / Format / More, contextual selection/link/image controls, mode switch, shortcuts, links, mentions, quotes, similar-topic guidance | Representative mixed content survives all supported actions, undo/redo, mode changes and panel dismissals |
| 4. Build insertion and media flows | Native upload pipeline, multiple-image/partial-failure UI, alt text, poll/table/date and agreed details/spoiler/code behavior | Insert/edit/cancel/retry/remove operate on native content and never persist mockup UI or discard surrounding text |
| 5. Build recovery and completion | Native draft status/close/resume/conflicts, field validation, permission/session failures, busy state, submitted/edited/pending outcomes | Fault tests preserve recoverable work; no false saved/published state or repeated submission |
| 6. Integrate conditional forms | Native form templates, validation, preview and the approved category-switch policy | Tested against a configured test category; excluded from launch if D8 defers it, with the decision visible |
| 7. Review and release | Cross-device, accessibility, visual and native-regression acceptance; staged preview, user review and rollback rehearsal | All launch cases pass, remaining deviations are explicitly accepted, and user authorizes rollout |

Stages 2–6 must each pass their own keyboard, accessibility and responsive
checks. Stage 7 is the cross-feature audit, not the first accessibility pass.
Detailed effort estimates come after stage 1; the unknown integration work
does not justify a confident calendar estimate now.

## Stage 0 — product decision register

The third column preserves the original recommendations made before Ismail's
2026-09-30 direction. The current disposition is in [17]. D1–D2 and D8–D10
are deferred; D3–D7 use native Discourse behavior for the current scope.
Where this differs from r1, record the affected design frames and copy before
approving an implementation reference. Do not infer that a configurable
setting or a particular native recovery flow exists without checking it.

| ID | Decision in v4 handoff | Recommended resolution |
|---|---|---|
| D1 | Tablet docked portrait / automatic full height in landscape with software keyboard | Keep the v4 behavior as the target; prove keyboard/rotation continuity in stage 1 before fixing implementation rules |
| D2 | More versus native Options wording | Use a scoped, translated Fomio label if needed; preserve global site overrides |
| D3 | Draft changed elsewhere: Copy / force-save mine / use other version | Keep all three only if native conflict semantics support them; require a clear overwrite confirmation and preserve access to the current text until replacement succeeds |
| D4 | Closing an unsaved offline composer | Keep v4's blocked close with Retry/Copy and an explicit separate discard path; never imply local persistence |
| D5 | Switching away from a filled guided form | Carry answers into text only if native composition can do so faithfully; otherwise propose a non-destructive stay/explicit-discard choice for approval |
| D6 | Sheets for details, spoiler and code | Target the v4 sheets, but prove native insertion and reopening; do not substitute direct-template actions without an agreed design revision |
| D7 | Failed link-preview note | Keep the quiet note/retry only if native failure can be distinguished from unsupported URLs; always retain the original link |
| D8 | Ship a guided form now? | Defer activation until a real category and template are approved; retain the conditional design and compatibility checks |
| D9 | Emoji discoverability | Recommend retaining the native tool under More; explicitly resolve the handoff's competing no-emoji rule |
| D10 | Session expiry | Restore the writing after login and require manual resubmit; avoid an unexpected automatic post |

Also resolve the large-text treatment: a saved-status icon may be compact,
but unsaved/error state must remain understandable without hover or a screen
reader. Confirm the full state can be revealed by keyboard and touch.

Freeze copies of `06 Composer`, `06.1 Composer Prototype`, the handoff,
`FmComposer4` and `fmc4-lib.js`, plus tokens and screenshots of reference
states. Record an export date and revision/hash; mutable project links alone
are not a durable baseline. Preserve v3 as historical comparison.

## Stage 1 — native feasibility gates

Use research evidence IDs in doc 09 as starting points, not a guarantee that
an API supports the full mockup. Read the current call sites and parameters.

| Gate | Candidate native surface | Proof required before proceeding |
|---|---|---|
| Toolbar and panels | `onToolbarCreate`, native popup options; E04/E16/E19 | Both editor modes, contextual state, stable selection, undo/redo and native shortcuts; real touch and keyboard activation, not pointer-only handlers |
| Keyboard and tablet layout | Native composer container/resizer and browser viewport; E03/E04 | Format stays usable with software keyboard; correct More behavior by layout; rotation/split/fullscreen transitions preserve the editor instance and pending work |
| Upload UI and alt text | Native Uppy lifecycle and image representation; E12/E16/E19 | Reliable per-file status/cancel/retry/remove, accessible alt editing and round-trip; no private upload backend or custom stored image nodes |
| Draft/close/conflicts | Native composer service/model and draft protocol; E02/E07 | Actual save completion/error/sequence semantics; distinguish a draft conflict from a stale post edit; do not treat `force_save` existence as sufficient proof |
| Error presentation | Native save-error callbacks and draft handling; E05/E06/E18/E19 | Correct error categories and permitted recovery without swallowing native errors or claiming frontend authorization |
| Advanced content/forms | Native builders and form-template model; E16/E19/E24 | Real rendered content, lossless serialization/edit reopening, conditional availability and non-destructive category changes |

Earlier experiment observations: native menu actions waited for keyboard
closure, and crossing mobile/desktop widths could duplicate or hide Upload.
These are regressions to reproduce and resolve, not accepted v4 behavior.

For each gate record: verified supported API, version-sensitive adaptation,
or unsupported. If the requested behavior cannot be delivered without
changing core, stop that feature and bring a concrete design alternative
back to the user. A plugin/core change is a separate scope decision.

Use a development Discourse with disposable users, categories and content
for error injection, uploads, posts and conflicts. A non-default theme on
meta.fomio.app still uses the real backend and is not a test database.
Before preview uploads, verify the actual destination and default theme;
never assume stored watch configuration is safe. Audit and isolate the old
theme-38 experiment before reusing it. Do not reset unrelated local work.

## Traceability from design to delivery

Create one acceptance record per named frame/subcase during stage 0. Each
record contains: reference revision + frame/prototype link; user intent;
viewport/input/editor/role conditions; native component/API; implementation
file; expected action and recovery; design status; integration status;
test evidence; remaining deviation and who accepted it.

| Design coverage | Primary stage | Must prove |
|---|---|---|
| C01–C03, M1 | 2 | Correct new-topic context, permitted destination and audience, no fixed category list |
| C04–C05, M2–M3 | 3 | Continuous writing, native mode conversion and optional preview, preserved selection |
| C06-1…9 | 4 | Picker/paste/drop, cancel, multiple/partial failures, alt text, upload-related action availability |
| C07-1…7 | 3 | URL loading/success/plain-link fallback/failure; hyperlink insert/edit/remove/cancel |
| C08-1…12 | 3–4 | Conditional native tools, actual content editing and mention keyboard behavior |
| C09 | 3 | Guidance never covers writing or preview; collapse/dismiss remain available |
| C10-1…6 and tablet quote | 3 | Topic/person/quoted reply, attribution, multiple quotes and correct destination |
| C11 | 2 + 5 | Reply edit versus first-post edit, eligible metadata, reason and saved-edit return |
| C12-1…9, C14–C15 | 5 | Save/close/minimize/resume, failed/offline saves and separate conflict types |
| C13 and C19 subcases | 5 | Local/server validation, revoked access, closed topic, session expiry; text retained |
| C16-1…5, C17 | 5 | Busy/double-submit prevention, accurate created/edited/pending outcomes |
| C18-1…5 | 6 | Native form validation/preview and agreed switch behavior, conditional activation |
| TAB-1…10, D-1…3 | 1–7 | Stable touch/hardware input and state across all layouts; real content, not just empty frames |
| A-1…6, A-4-D, L1/L2 | Every stage | Focus, announcements, zoom, long content, direction, motion and accurate audience |

Tags/AI and non-image attachments remain outside this design's launch scope,
subject to re-checking configuration. PM/staff/whisper/shared-draft designs
are out of scope; existing native functionality must not be hidden or broken
for accounts that legitimately use it. Gate new behavior to supported cases
and retain the native fallback.

## Acceptance matrix and evidence

Reference sizes: phone 360×740 and 390×844; split view 375×834 and 600×834;
tablet 834×1194 and 1194×834; desktop 1280×800. Also test widths around the
actual chosen breakpoints. Tablet behavior must follow usable viewport and
input conditions, not a guessed device name or only `site.mobileView`.

Mandatory transition test: begin with mixed content and a selection, start
multiple uploads, open Format/More, rotate portrait → landscape → split view
→ wide view, then resume typing. Text, selection, upload identity, draft
state and the single primary action remain coherent; no missing/duplicate
Upload, blocked caret or editor remount.

For each stage:

1. Compare reference and implementation with identical content, state,
   dimensions, theme and direction. Inspect paired screenshots/overlays for
   hierarchy, alignment, wrapping, target sizes and panel placement. Approve
   semantic/layout differences explicitly; do not hide them in a pixel score.
2. Exercise real native commands and persistence in integration tests. Verify
   mixed-content save/reopen and rich ↔ Markdown conversion, undo/redo,
   intended requests and response outcomes. UI errors/progress must not leak
   into stored post content. Avoid new duplicate requests or subscriptions.
3. Check keyboard navigation and focus restoration in every new panel; modal
   focus stays inside, Escape closes the top layer, validation focuses the
   field, and async errors are announced without repeated chatter. Do not
   blindly assign `alertdialog` to every ordinary form dialog.
4. Exercise phone/tablet Safari and Android Chrome with physical software
   keyboards, selection handles, composition/IME, safe areas, hardware
   keyboard and trackpad. Browser resizing is useful but is not this proof.
5. Check VoiceOver/TalkBack and desktop screen-reader coverage, actual 150%
   and 200% zoom, platform font scaling, light/AMOLED, RTL and mixed text,
   long translated labels and reduced motion. Explicitly record unavailable
   device checks as pending rather than passed.
6. Run the repository's native, variable, SCSS and duplication guards against
   the matching source export, plus meaningful new interaction/acceptance
   tests in development Discourse. Existing host-stubbed Toolbar tests alone
   do not establish editor integration or accessibility.

Stop release for content loss, silent overwrite, false saved/published
claims, duplicate posting, permission leakage, inaccessible primary actions
or unresolved keyboard/viewport failures. Smaller visual deviations still
need documented acceptance; they do not become the design by default.

## Review, rollout and maintenance

Show the user each completed stage with reference/implementation comparison,
working preview, tested cases and remaining deviations. A failed gate sends
the affected feature back to design; unrelated verified work can continue
within the authorized scope. Do not silently replace the compact Format
tray with a long native menu and call it equivalent.

After stage 7: freeze the candidate version and settings record, retain the
previous known-good theme, obtain rollout approval, and verify the selected
theme target immediately before deployment. Rollback restores presentation
without deleting posts, uploads or drafts; rehearse returning to the native
composer with an existing draft. Re-run the critical command, draft and
tablet-transition suite after Discourse upgrades.

No commit, push, preview upload or implementation is part of this roadmap
task. The immediate next milestone is **stage 0: lock the reference and
decisions**, followed by separately authorized stage 1 work.
