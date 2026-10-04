# 14 — Composer v4, stage 0: reference lock record

Prepared 2026-09-30; revised the same day after an audit request. **This
record is for review. It does not start implementation.** The v4 design is
still marked "awaiting approval, not for implementation" in the design project.
Doc 12's stage 0 exit condition is still open. The user must approve this
version and settle D1–D10 and LT (large-text status). Stage 1 needs a separate,
explicit authorization. Nothing here settles a pending decision. The v4
direction and delivery sequence in doc 12 are unchanged.

**Location (2026-09-30):** copied into the repository at the user's request,
after the `discourse_theme watch` process was stopped. Supporting files are in
`docs/composer-v4-stage-0/`:

| Path | Contents |
|---|---|
| `composer-v4-reference/` | Frozen snapshot + render-deps addendum, each with `MANIFEST.sha256` |
| `composer-v4-*.csv` | Acceptance records, copy mapping, screenshot plan |
| `screenshots/` | 44 PNGs, `SCREENSHOT-MANIFEST.csv`, `capture-log.json` |
| `tooling/` | `capture.mjs`, `make_harness.py`, `shots.json`, `harness/_shot_*.dc.html` |
| `RECORDS.sha256` | Hashes of both records and all supporting manifests; run from `docs/` |

To reproduce the screenshots:

1. Copy `composer-v4-reference/2026-09-30/`, then the addendum's `mockups/` and
   `tooling/harness/*`, into one render folder.
2. Serve it on 127.0.0.1:8765.
3. Run `node tooling/capture.mjs <shots.json> <outdir>`.

Capture needs the locally cached Playwright Chromium headless shell and
network access to unpkg, Google Fonts and jsdelivr.

Scope of the audit pass:

- The work was done in a scratch folder only.
- The repository, the theme watcher and the design source were not changed.
- Discourse source was read with `git show 7b4f0970…:<path>` from
  `/Volumes/Develop/Projects/Fomio/discourse`. This reads commit objects only.
  That checkout's working tree (HEAD `b2d5dcd8`, with local modifications) was
  not touched.

Source keys used in the records:

| Key | Source |
|---|---|
| R | `06 Composer.dc.html`: frame notes (R `<id>`) and section notes (R§`<section>`) |
| COV | Coverage table in R |
| PH | Prototype hints in `06.1` |
| LIB | Presets and builders in `fmc4-lib.js` |
| FMC4 | Behaviour and copy in `FmComposer4.dc.html` |
| HO§n | Handoff section n |
| CORE | Discourse source at `7b4f0970` |

## 1. Snapshot identity (unchanged)

| Field | Value |
|---|---|
| Design project | "Fomio design system planning", `10e05e50-973c-4ddb-836f-406e5456a4f2` |
| Export date | 2026-09-30 (Asia/Amman) |
| Method | Read-only `get_file`; contents written byte-for-byte and hashed with SHA-256 |
| Server revision | Not exposed by the connector. The hashes are the identity. |
| Snapshot ID | `bcea0ad522425713fa203f8d23e0d8efc2590ad9b77089b4757d30e44122da9a` (SHA-256 of `MANIFEST.sha256`, 20 files) |

The frozen file table is in `composer-v4-stage-0/composer-v4-reference/2026-09-30/MANIFEST.sha256`.
The roles and sizes are the same as the first version of this record.

## 2. Flag: the sample screenshot is JPEG data

`screenshots/v4-a.png` has a `.png` name, but its contents are JPEG. The
evidence:

- magic bytes `FF D8 FF E0`, JFIF 1.01
- the connector reports `contentType: image/jpeg`
- it is 924×540, which is **none** of doc 12's reference sizes
- it carries embedded content-credential metadata

It isn't a reference-state capture. It only shows that project filenames don't
reliably state the file format. The other 200+ project screenshots weren't
fetched, so their formats are unknown. Any future screenshot baseline must
record the sniffed format and the pixel size, not trust the extension.

## 3. Screenshot requirement, reassessed

Doc 12 asks for "screenshots of reference states". It does not ask for one per
acceptance row. The proposal is a **representative, traceable set of 44
states**, listed in `composer-v4-stage-0/composer-v4-screenshot-plan.csv`. **All 44 were captured
on 2026-09-30 (§3a).**

> **What these screenshots are and are not.** They are renders of the frozen
> v4 *design prototype* (FmComposer4 fixtures, a simulated keyboard, simulated
> network and upload states), captured in desktop headless Chromium. They are
> the visual reference for stage 0. They are **not** screenshots of Discourse,
> and not evidence of native composer behaviour, rich-editor rendering, real
> keyboards or safe areas, iOS/Android devices, or assistive technology. Every
> acceptance row keeps "Integration status: Not started".

- **What it covers:**
  - every IA group C01–C19
  - each delivery stage 1–7
  - all 7 reference viewports (390, 360, split 375, split 600, 834×1194,
    1194×834, 1280)
  - both schemes
  - RTL, 150% zoom and a hardware keyboard
  - every pending decision: D1 (S32–S37), D2/D9 (S16, S37), D3 (S23), D4
    (S22), D5/D8 (S31), D6 (S17), D7 (S08), D10 (S27), LT (S20, S40, S41)
  - inconsistency I-1: both meanings of TAB-9 (S06, S07)
- **How it traces:** each acceptance row now has a `reference_screenshot`
  column. 42 rows point to an exact shot. The rest name their group's
  representative shot and keep the prototype link, which renders the exact
  state on demand.
- **S41 is deliberately not a named frame.** It shows C12-4 (unsaved status) at
  150% zoom. The LT concern is exactly that unsaved states become icon-only
  below 330 CSS px (`FMC4 ds.wide = W >= 330`), and no named frame shows that.
- **Filename rule:** `S##__<frame>__<WxH>__<scheme>[__mods].png`. Record the
  SHA-256, the sniffed format and the pixel size at capture.
- **Capture source used:** the frozen snapshot plus the render-deps addendum,
  rendered at the stated size (§3a). A design-project export was not used. The
  per-file SHA-256, format and pixel size are in the plan CSV and in
  `composer-v4-stage-0/screenshots/SCREENSHOT-MANIFEST.csv`.
- **Limits:** reduced motion (A-6) and focus behaviour can't be proven by stills.
  Those rows keep behavioural evidence as their acceptance basis.

### 3a. Capture result (2026-09-30): 44 of 44 captured

- **Where:** `composer-v4-stage-0/screenshots/` holds 44 PNGs and `SCREENSHOT-MANIFEST.csv`. Each
  entry records the file SHA-256, the sniffed format (all PNG), the pixel size,
  the props, the harness file and its hash, readiness checks, a visual-review
  note and limitations. `TOOLING.sha256` pins the capture script, the harness
  generator and the shot list.
- **Method:** the frozen snapshot, plus the addendum below, was copied to
  a render folder and served on 127.0.0.1 only. Each shot is a one-component harness
  page that imports `FmComposer4` with the review page's props. Captures used
  the locally cached Chromium headless shell (HeadlessChrome/153.0.8010.12)
  over DevTools, at 1× scale. Each capture waited until the frame was ready and
  Source Sans 3, Roboto Slab and Font Awesome 6 had loaded. React, Babel and
  the fonts load from their public CDNs, as in the design project.
- **Visual review:** all 44 match their planned states. Recorded limitations:
  - S03 and S09: the selection is hidden behind the tray (I-12).
  - S07: a static state; the rotation transition itself can't be a still.
  - S20 and S28: spinners are frozen in a still.
  - S37: the review preset has no keyboard up.
  - S40 and S41: the frame is 844.5 CSS px tall at 1.5× and the image is
    clipped to 844.
- **Blocker found and resolved: I-11.** `FmComposer4` imports `FmHeader` and
  `FmBottomNav`, which weren't in the 20-file snapshot. Attempt 1 therefore
  rendered page views with blank header and bottom-bar boxes (S06, S07, S15 and
  S29 logged 404s). Both files were fetched read-only into
  `composer-v4-stage-0/composer-v4-reference/2026-09-30-addendum-render-deps/`:
  - FmHeader `3bff5cfe…`
  - FmBottomNav `c7fecaaa…`
  
  Neither imports anything further, so the closure is complete. Attempt 1 was
  kept in the session scratch folder as a partial result; it isn't part of the
  repository package. The original snapshot ID
  `bcea0ad5…` is unchanged; the approval should cover the snapshot **and** the
  addendum.
- **Benign console error:** every shot logs one `TypeError … 'GEO'`. It comes
  from the first render before `fmc4-lib.js` loads, and all frames then report
  `ready`.
- **Not attempted:** the design project's own 200+ screenshots. They aren't
  needed, because this set was rendered from the frozen source.
- **Not reproducible offline:** captures depend on unpkg, Google Fonts and
  jsdelivr being reachable.

## 4. Frame inventory and inconsistencies

- 98 review frames and 102 prototype routes.
- 110 acceptance records: 98 review frames, 9 prototype-only routes, 2 aliases
  and 1 missing ID.

| # | Finding | Evidence |
|---|---|---|
| I-1 | TAB-9 means two things: "destination sheet" in the review vs "uploads during rotation" in the prototype | R TAB-9; PH GROUPS |
| I-2 | C12-6 doesn't exist, though the handoff claims C12-1…9 | R, PH, LIB |
| I-3 | C13-1 and C14-1 exist only as lib aliases (of M6 and M6b) | LIB |
| I-4 | Every dialog is `role="alertdialog"`; doc 12 warns against doing this for ordinary dialogs | FMC4; HO§7 |
| I-5 | The handoff and prototype make draft status icon-only below 330px; the review page mentions only the strip | FMC4; HO§7 |
| I-6 | Tokens say "Source Sans 3"; the design context says "Source Sans Pro" | tokens vs design context |
| I-7 | COV marks C06·a, C15, C18, TAB and A11Y as Partial | COV |
| I-8 | **New.** HO§6 labels about 16 strings as "core fixtures" that don't match core at `7b4f0970`, for example Saving draft… (core "Saving"), Overwrite Edits (core "Overwrite Edit"), Keep editing (absent), Unable to connect. (absent), Insert Hyperlink (core "Insert link"), Poll must have at least 2 options. (core minimum is 1), This field is required (core "Please fill out this field.") | copy mapping CSV |
| I-9 | **New.** FMC4 defines a `noReply` banner ("You can no longer reply here.") that no named frame or coverage row uses | FMC4 BN.noReply |
| I-10 | **New.** The sample screenshot is JPEG, and at a non-reference size (§2) | `file`, `xxd` |
| I-11 | **New.** The snapshot wasn't dependency-closed: `FmHeader` and `FmBottomNav` were missing. Resolved by the addendum (§3a). | capture attempt 1 |
| I-12 | **New.** At 390×844 the M3 Format tray and the C07-6 link tray cover the selected text the frames say is kept. This is a mechanical correction for the design. | S03, S09 |

Corrections and copy are grouped for review in
`15-composer-v4-copy-and-corrections-sheet.md`. That sheet separates
mechanical design corrections (A) from native-wording defaults (B),
intentional label changes (C), new labels (D) and product choices (E).

## 5. Decision register: all pending

Each question is unchanged from the first version of this record, as are the
v4 options and doc 12 recommendations. This pass adds **native evidence at
`7b4f0970`** that the user may want before deciding. It is source reading only:
nothing was run against a live or development server. None of it decides the
question.

| ID | Question (pending) | Native evidence found (source only) |
|---|---|---|
| D1 | Tablet docked/auto-full-height vs always full height | None new. Device behaviour needs stage 1. |
| D2 | "More" as a new key vs overriding "Options" | Composer menu key is `composer.options` = "Options". Generic `more` = "More" exists but isn't the composer key. |
| D3 | Draft changed elsewhere: 3 actions vs 2 | On a 409, `DraftsController` returns `draft.sequence_conflict_error` ("Draft is being edited in another window. Please reload this page."). `models/composer.js` shows an alert with **Reload** (`composer.reload`) and **Ignore** (`composer.ignore`). Ignore sets `draftForceSave`. There is **no native Copy action**, and there's no in-place "use other version". Native "Reload" reloads the page. |
| D4 | Offline close: block vs confirm-lose | Every non-409 draft failure sets `draftStatus` to `composer.drafts_offline` ("drafts offline"). Core doesn't distinguish offline from failed. The native discard modal (`cancelComposer`) only offers Discard or Cancel. Native close-on-failure behaviour is not traced (stage 1). |
| D5 | Guided-form switch: carry answers vs block | Not traced. The form-template model is a stage 1 gate. |
| D6 | Details/spoiler/code: sheets vs direct insert | Core keys `details.title`, `spoiler.title` and `composer.code_title` exist. v4's claim that these insert templates directly is consistent with them, but the call sites were not re-read in this pass. |
| D7 | Keep the preview-failure note? | In the rich editor (`prosemirror/extensions/onebox.js`), an **empty result and a fetch error are both recorded in `failedUrls` with no message**. The toast `composer.link_toolbar.preview_failed` ("Could not load preview") appears only on a forced retry from the link toolbar ("Load preview"). The two cases are separate code branches, but core treats them the same. Markdown mode was not traced. |
| D8 | Ship a guided form before a real category exists? | Product decision; no source bearing. |
| D9 | Emoji under More vs hidden | `composer.emoji` "Emoji :)" and `composer.more_emoji` exist. The source of the "no-emoji UI rule" is still unidentified. |
| D10 | Session expiry: manual vs automatic resubmit | Core `logout` = "You were logged out."; server `not_logged_in` = "You need to be logged in to do that." The login-return flow is not traced. |
| LT | Large-text draft status | As built, **every** draft state is icon-only below 330 CSS px (A-1 at 150% on a 390px phone is 260px). Core has only two draft-status strings: `composer.saving` "Saving" and `composer.drafts_offline` "drafts offline". Doc 12's recommendation stands: saved may be compact; unsaved, offline, failed and conflict stay readable and can be revealed by keyboard and touch. |

The user also needs to confirm two things for the stage 0 exit:

- **Exclusions:** PM, staff actions, whispers and shared drafts are not
  redesigned but must not break. Tags and AI are excluded. Non-image attachments
  are excluded. C18 is conditional on D8.
- **Copy mapping:** approve it (§7).

## 6. Acceptance records (`composer-v4-stage-0/composer-v4-acceptance-records.csv`)

The 110 rows now carry cited, specific content:

- **User intent and expected action/recovery** are filled from the frozen design
  on 106 rows. **TO CONFIRM remains only where the design itself is ambiguous:**
  TAB-9 (I-1), C12-6 (I-2), C13-1 and C14-1 (I-3).
- **`design_sources`** cites the exact R, COV, PH, LIB, FMC4 or HO location.
- **`native_evidence_7b4f0970`** records the matching core string or call site
  where one was found. This is source evidence, not integration evidence.
- **`test_evidence`** is split into three tiers:

| Tier | Rows |
|---|---|
| Itemised scripted check in HO§11 | 50 |
| Group-level COV status only, not itemised | 52 |
| No test recorded | 5 |
| No own frame (alias or missing) | 3 |

  Every tier states that there is no Discourse integration, device or
  assistive-technology evidence.
- **`reference_screenshot`** links each row to §3's plan.
- **Unchanged:** `implementation_file` stays "Not authorized — none";
  `integration_status` stays "Not started"; deviations stay "—".

## 7. Copy mapping (`composer-v4-stage-0/composer-v4-copy-mapping.csv`)

101 strings from HO§6 (the approval dialog was split into title and body after capture) (proposed strings and claimed core fixtures), checked
against the pinned locale files:

- core client/server `en`
- poll, discourse-local-dates, discourse-details and spoiler-alert

| Result | Count | Meaning |
|---|---|---|
| CORE-EXACT | 31 | Render with the core key; no override. Examples: Edit link, Remove link, Timezone/Date/Time, Options (one per line), Post Needs Approval, Reply as linked topic, You were logged out. |
| CORE-DIFFERENT | 33 | Core covers the concept with different wording. The production label is the core output unless the user chooses a site-text override. Examples: Alt text → "Add image description"; Bullets → "Bulleted list"; the claimed fixtures in I-8. |
| CORE-NEAR | 15 | A related key exists on another surface. Reusing it is a scoping or override decision. Examples: Photo → `composer.upload_title` "Upload"; More → `composer.options` (D2); Copy text → `link_toolbar.copy`. |
| NONE | 21 | No core key found. Each needs a user decision: a theme key with a stated reason (doc 13 rule 6), or a redesign. Examples: Format, Hide keyboard, Retry save, Keep editing, Choose another category, most draft/conflict banners. |
| NOT-UI | 1 | Simulated keyboard (prototype only). |

The existing site-text overrides stay as they are. Observed live wording is
"New Byte", "Create topic" and "Byte". None of the rows proposes copying their
wording into theme literals.

This mapping records evidence. **It does not approve any override or new key.**

## 8. Approval checklist (stage 0 exit)

- [ ] Resolve or accept I-1…I-12 (see sheet 15 §A). If the design is revised, re-snapshot and re-capture.
- [x] Captured the 44-shot representative set against snapshot `bcea0ad5…` + render-deps addendum (§3a). Reviewer to accept or amend.
- [ ] User approves snapshot `bcea0ad5…` **plus** the render-deps addendum as the v4 reference.
- [ ] User decides D1–D10 and LT, and records the result in doc 12.
- [ ] Confirm the exclusions. Approve the copy mapping per row: core output,
      override, new key or redesign.
- [x] Placed the snapshot and records in `docs/` (2026-09-30), after stopping the theme watcher.
- [ ] **User explicitly authorizes stage 1.** Until then: no implementation,
      preview upload or deployment.
