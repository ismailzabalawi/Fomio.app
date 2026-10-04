# Composer v4, stage 0: r1 reference lock record

Prepared 2026-09-30. **This record is for review. It does not start stage 1.**
Ismail authorized the design corrections and the recapture. Approving r1 as the
v4 reference, and every product choice below, is still open.

This record supersedes stage 0 baseline `bcea0ad522425713…` as the *proposed*
reference. The original stage 0 files are unchanged and remain the historical
baseline. Paths below are relative to this folder.

## Reference

| Item | Value |
|---|---|
| Snapshot | `composer-v4-reference/2026-09-30-r1/`: 22 files, dependency-closed (includes FmHeader and FmBottomNav) |
| **Snapshot ID** | `1155798935fd3fc5826aed5fb96ad7736e5b4bfeb4afbd6de4169f6d20e89f9a` (SHA-256 of its `MANIFEST.sha256`) |
| Design project | "Fomio design system planning", `10e05e50-973c-4ddb-836f-406e5456a4f2` |
| Export | 2026-09-30. Every file was read fresh from the server after publishing. Server bytes equal the published copies; the 14 unchanged files equal baseline `bcea0ad5…` plus its addendum. |
| Frames | 100 review frames (98 + TAB-11 + C13-6) and 104 prototype routes |
| Screenshots | `screenshots/`: 48 PNGs, `SCREENSHOT-MANIFEST.csv`, `capture-log.json` |
| Screenshot plan | `composer-v4-screenshot-plan-r1.csv`, with real SHA-256 and capture metadata for every shot |
| Acceptance records | `composer-v4-acceptance-records-r1.csv`: 112 rows |
| Copy mapping | `composer-v4-copy-mapping-r1.csv`: 103 rows |
| Tooling | `tooling/`: edit scripts, harness generator, capture script, shot list, 48 harness pages |
| Hashes | `RECORDS-r1.sha256` |

## Exact design changes (publish plan `plan_10e05e50973c4ddb_5ac63af419d4`)

| Path | Change | Baseline SHA-256 | r1 SHA-256 |
|---|---|---|---|
| `mockups/FmComposer4.dc.html` | modified | `2291e6b03c5c…` | `4fca9bf56a40…` |
| `mockups/fmc4-lib.js` | modified | `6118e240dad3…` | `22035d6f3531…` |
| `mockups/06 Composer.dc.html` | modified | `08d6c5d6bb54…` | `51ebfb5402d7…` |
| `mockups/06.1 Composer Prototype.dc.html` | modified | `b4664802819a…` | `a93aff11997d…` |
| `mockups/06 Composer handoff.md` | modified (new §12 revision log) | `11c230caf70f…` | `44282375b07c…` |
| `mockups/README.md` | modified | `4bab5ccb28e7…` | `ca996efd45a2…` |
| `tokens/core-variables.css` | modified (comment only) | `20a0125faa5e…` | `32a54027a5e9…` |
| `screenshots/v4-a.png` → `screenshots/v4-a.jpg` | renamed; same bytes | `a4e7fc008172…` | `a4e7fc008172…` |

Full hashes are in each snapshot's `MANIFEST.sha256`. The per-edit log, with an
audit ID for each edit, is in handoff §12 and in `tooling/apply_r1.py` and
`tooling/apply_r1_handoff.py`.

## Audit results

| Audit IDs | Status in r1 | Evidence |
|---|---|---|
| A1, I-8 | Fixed: native surfaces use verified core wording | S16, S18, S20, S24, S30, S47, S48, S06 |
| A2 | Fixed: poll minimum 1; duplicates show core wording | S18 |
| A3 | Fixed as a claim: Keep editing / Save draft for later are now proposed copy | S46 |
| A4, I-1 | Fixed: TAB-9 = destination sheet; TAB-11 = uploads during rotation | S06, S07 |
| A5, I-2, I-3 | Fixed: C12-6 unused; C12-7 = M5, C12-8 = M5b, C13-1 = M6, C14-1 = M6b | AR-110 (C12-6); AR-101, AR-040, AR-108, AR-109 (aliases); TAB-9 is AR-019 |
| A6, I-9 | Fixed: C13-6 framed | S45, AR-112 |
| A7, I-12 | Fixed: the selection is visible with 32–33px clearance (DOM check) | S03, S09, S34 |
| A8, I-4 | Fixed: alertdialog only for discard and replace (DOM roles) | S46 vs S30, S31 and the sheets |
| A9, I-11 | Fixed: the snapshot is dependency-closed | 0 fetch errors in 48 captures |
| A10, I-10 | Fixed: `v4-a.jpg` | server file list |
| I-5, I-6 | Fixed as documentation; LT itself stays pending | review page, tokens, README |
| I-7 | Unchanged: approval judgement (Partial coverage) | — |

## Still pending (not decided)

- **D1–D10** and **LT**. S41 shows the unsaved status as icon-only at 150%
  zoom; S40 shows the saved status.
- **P-1** Discard dialog actions: native Discard + Cancel, or v4's three actions
  (S46).
- **P-2** Offline submit banner title: "Unable to connect." or the core network
  error wording.
- **P-3** Persistent draft-status wording (Draft saved / Draft not saved /
  Offline. Draft not saved); tied to D4 and LT.
- **P-4** Destination search accessible name: "Search categories" or the core
  "Search…" alone.
- Section C labels, and the keep-or-drop choice for each Section D group
  (copy mapping rows marked *Pending*).
- Exclusions (PM, staff, whispers, shared drafts; tags and AI; non-image
  files), and approval of r1 as the reference.

## Evidence limits

- The screenshots are **simulated frozen-design renders** from the prototype
  component in headless Chromium. They are not Discourse, device, keyboard or
  assistive-technology evidence.
- The handoff §11 scripted interaction checks ran on the **pre-r1** revision
  and were not re-run. r1 is covered by static renders and two DOM checks
  (dialog roles and selection visibility) only.
- **Still-image limits:** S07 is a state, not the rotation transition. S20 and
  S28 spinners are frozen. S37's preset has no keyboard up. Reduced motion
  can't be shown in a still.
- The poll builder-vs-server timing, native close-on-failure and all other
  stage 1 gates are unverified.
- The formats of the design project's 200+ historical screenshots are
  unchecked.
- **Capture depends on CDNs:** unpkg (React and Babel), Google Fonts and
  jsdelivr (Font Awesome).
- **Operator error during capture:** the first S27 file was overwritten by a
  review command before hashing. It was recaptured (`capture-log.json` note)
  and verified at 390×844 PNG.
- `review_link` and `prototype_link` point at the live design project, which
  can change. **The snapshot is the authority.**
