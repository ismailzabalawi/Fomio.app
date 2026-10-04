# 18 — Composer v4 r1 reconciliation for review

Prepared 2026-09-30 after [Ismail's D1–D10 direction](17-composer-v4-decision-update.md).
Ismail subsequently approved the five recommendations in this sheet on
2026-09-30. That approval sets the policy below; it does **not** approve every
r1 frame as a build target or authorize Stage 1.
This is a review overlay on the immutable [r1 package](16-composer-v4-stage-0-r1.md),
not an edit to its snapshot, 48 captures, acceptance CSV, copy CSV or hash
manifests. The r1 package records what the design showed at capture time. This
sheet records where that design is now **future scope** or differs from the
**current native Discourse target**. It does not approve r1 or Stage 1.

The r1 acceptance CSV has 112 records. Thirty-five unique records explicitly
name at least one of D1–D10 in its `decisions` field; some carry multiple IDs.
The table below lists those record IDs. Related copy may occur in other frames,
so a record not listed here is not proof that its wording is unaffected.
The [supplemental acceptance overlay](composer-v4-r1-disposition/acceptance-disposition.csv)
lists all 35 rows individually. The [copy overlay](composer-v4-r1-disposition/copy-disposition.csv)
lists affected r1 copy entries and their approved default treatment.

| Decision | r1 records and primary visual evidence | Reconciliation for current scope |
|---|---|---|
| D1 — tablet sizing | AR-011–020 (TAB-1–10), AR-034 (C10-5-T), AR-111 (TAB-11); [S32](composer-v4-stage-0-r1/screenshots/S32__TAB-1__834x1194__light.png), [S33](composer-v4-stage-0-r1/screenshots/S33__TAB-3__1194x834__light.png), [S35](composer-v4-stage-0-r1/screenshots/S35__TAB-5__600x834__light.png), [S07](composer-v4-stage-0-r1/screenshots/S07__TAB-11__834x1194__light.png) | Mark r1 docked/full-height rules as a **future settings review**, not a current build requirement. Preserve the native/configured layout for now. No suitable setting or rotation behavior has been verified. Retain the screenshots as design evidence. |
| D2 — More/Options | AR-010 (C05b), AR-018 (TAB-8), AR-054–055 (C08-1/2); [S16](composer-v4-stage-0-r1/screenshots/S16__C08-1__390x844__light.png), [S37](composer-v4-stage-0-r1/screenshots/S37__TAB-8__834x1194__light.png) | Defer the proposed “More” relabel. Keep native wording and existing site-text overrides until the later settings review. The r1 “More” copy row is not approval for a new key or global override. |
| D3 — draft conflict | AR-042–043 (C15-1/2); [S23](composer-v4-stage-0-r1/screenshots/S23__C15-1__390x844__light.png) | The three-action conflict banner and replace confirmation are **not current build targets**. Use verified native conflict behavior. The r1 Copy my text / Save mine over it / Use the other version / Replace copy is proposed visual evidence only. A source or runtime check must establish the actual native recovery and text protection. |
| D4 — offline save/close | AR-007 (M6b), AR-039 (C12-5), AR-107 (C14-2), AR-109 (C14-1 alias); [S22](composer-v4-stage-0-r1/screenshots/S22__C12-5__390x844__dark.png) | The blocked-close Retry/Copy/discard design in C12-5 is **not a current build target**. Use verified native draft and close behavior. M6b/C14 also show offline status and submit states; D4 alone does not establish what those native outcomes are. Do not claim text is saved or recoverable without evidence. |
| D5 — filled guided-form switch | AR-077 (C18-4); [S31](composer-v4-stage-0-r1/screenshots/S31__C18-4__390x844__light.png) | No custom answer-to-text conversion or switch dialog. D8 also defers activation, so C18-4 is future/conditional scope. If forms are later enabled, trace and verify native switching behavior first. |
| D6 — details/spoiler/code insertion | AR-057 (C08-4), AR-059–060 (C08-6/7), AR-062 (C08-9); [S17](composer-v4-stage-0-r1/screenshots/S17__C08-4__390x844__light.png) | The v4 details, spoiler and code sheets, plus their reopen/edit pattern, are **not current build targets**. Use actual native insertion controls and copy after verification. This decision does not decide the separate table or date builders. |
| D7 — failed link preview | AR-021 (C07-1), AR-024 (C07-4); [S08](composer-v4-stage-0-r1/screenshots/S08__C07-4__390x844__light.png) | Do not build the v4 “Preview unavailable…” note and Try again action. Preserve native link/preview handling and the pasted link. The loading state in C07-1 also needs native tracing; D7 does not eliminate all link-preview UI. |
| D8 — guided-form launch | AR-074–078 (C18-1–5), AR-098 (D-3); [S31](composer-v4-stage-0-r1/screenshots/S31__C18-4__390x844__light.png), [S47](composer-v4-stage-0-r1/screenshots/S47__C18-2__390x844__light.png) | Defer activation. Treat r1 form choice, validation, preview, switching and published states as **conditional future design**, not launch acceptance targets. Existing native form functionality must remain usable where already configured. |
| D9 — emoji discoverability | AR-010, AR-018, AR-054–055; [S16](composer-v4-stage-0-r1/screenshots/S16__C08-1__390x844__light.png) | Defer the emoji placement/removal choice. Do not treat its absence from the r1 More sheet as a requirement to hide a native tool. |
| D10 — session expiry | AR-048–049 (C19-4/5); [S27](composer-v4-stage-0-r1/screenshots/S27__C19-4__390x844__light.png) | Defer the proposed after-login restoration/manual-resubmit flow. Preserve native behavior. Do not promise either automatic or manual resubmission until the real outcome is traced. |

## Copy reconciliation

The [r1 copy mapping](composer-v4-stage-0-r1/composer-v4-copy-mapping-r1.csv)
is an as-captured inventory. Its pending strings should be reviewed against
this direction before any theme key or override is created:

| Treatment | Copy rows or groups | Reason |
|---|---|---|
| Defer with D2/D9 | “More”; emoji placement (no new string) | A later settings/toolbar review will decide the presentation. |
| Native target for D3/D4 | Draft-conflict text/actions/replace confirmation; offline blocked-close text and Retry save; draft-status wording | The custom recovery UI is not approved for the current build. `Copy text` and `Text copied` also occur in C13/C19, so they cannot be removed globally merely because D3/D4 use native behavior. The approved LT visibility requirement still needs native verification. |
| Native target for D6/D7 | Text to blur; Code/Language; details/spoiler/code sheet validation; “Preview unavailable…” and preview retry | These depend on custom sheets or a custom failure note. Native wording and actual capabilities need verification. Table/date copy is a separate question. |
| Future/conditional with D5/D8/D10 | “Switch to [category]?” and answer conversion; guided-form copy; session-expiry body and Copy text | No guided-form activation or custom session-expiry flow is approved now. Preserve the r1 strings as future design evidence. |
| Approved copy policy; exact labels need verification | Photo, Format, visible formatting names, audience labels, edit reason, upload and submission feedback, suggestions, C13-6 permission banner, and other Section C/D groups not tied to D3–D10 | Use native wording where it conveys the same action. Any distinct Fomio wording needs an explicit scope and i18n plan. Do not change the site's existing overrides by implication. |

The active Section C/D choices can be reviewed as four small groups. These
approved defaults preserve the design direction where it adds an actual surface,
while avoiding a new translation for a label that native Discourse already
renders. Exact strings still need checking at the target server version.

| Active group | r1 proposal versus known core wording at `7b4f0970` | Approved default policy |
|---|---|---|
| Writing strip | “Photo” versus “Upload”; “Format” has no core group key; “Hide keyboard” has no core key | Use the native Upload label for the upload action. Keep Format and an accessible Hide keyboard label only if those new controls remain in the approved shell; give each a scoped theme key. |
| Formatting and audience | Bold/Italic versus Strong/Emphasis; Public/“[Groups] only” versus Public/Private; “Add edit reason” versus the observed “Why are you editing?” placeholder | Use native action labels and actual audience terminology. Keep a distinct label only when it describes a verified distinct action or permission state. |
| Recovery, upload and submission feedback | Custom Copy text/Text copied in several error frames; “Drop images to upload,” upload-wait/failure strings, “Not posted” and other result titles | Reuse native error, upload and outcome wording. Decide separately whether an additional Copy text action is needed in still-active C13/C19 recovery states; D3/D4 alone do not settle those states. |
| Remaining insertion and guidance | Table/date labels and validation, “Suggestions,” editor-mode sub-lines, C13-6 reply-permission banner | Use the existing native table/date and mention wording where available. Keep a new banner or sub-line only if native feedback leaves a meaningful gap verified in the current product. |

## Approved direction and remaining evidence

Ismail approved the following recommendations as direction. Conditional
wording means a native capability or design necessity must still be verified;
it does not silently approve a new label or control.

1. **Reference rule:** Keep r1 frozen for traceability, with this exception
   sheet. Prepare a separately documented build reference after the affected
   records are reconciled. Review that build reference for approval later;
   do not call every r1 interaction a build acceptance target now.
2. **LT — visible unsaved/error state:** [S41](composer-v4-stage-0-r1/screenshots/S41__C12-4__390x844__light__zoom1.5.png)
   shows an icon-only unsaved status at 150% zoom. Require visible status
   text at large text/zoom, with keyboard and touch access; verify it in the
   eventual native UI. This is independent of exact draft-status wording.
3. **P-1–P-4 defaults:** Use the native discard flow for P-1 under D4,
   native/core network wording for P-2, and native draft-status behavior for
   P-3 subject to the LT visibility requirement. Use the descriptive
   accessible name “Search categories” for P-4 even if the visible
   placeholder remains “Search…”. Verify current native strings and controls
   before recording exact build copy.
4. **Intentional copy:** For Section C and the remaining Section D groups,
   use native wording by default. Keep only Fomio labels needed to distinguish
   a real new action or state, with a scoped translation key and a reason.
   The likely exceptions are Format, Hide keyboard, a Copy text recovery
   action outside D3/D4, and any permission banner that native feedback does
   not cover. Their necessity remains an evidence question, not an approved
   exact string.
5. **Exclusions:** PM, staff, whispers and shared drafts are not redesigned,
   while their existing native functions remain available; tags/AI and
   non-image files are outside this redesign's launch scope. This excludes
   a redesign, not native fallback functionality.

## Before reference approval

- Use the supplemental acceptance/copy overlays linked above to carry the
  approved direction into build-reference review. Keep the frozen r1 CSVs
  and hashes unchanged. Exact native outcomes and labels remain unverified.
- Verify the relevant native behavior and settings at the actual target
  Discourse version before claiming equivalence. The original research at
  `7b4f0970` is a starting point, not current runtime proof.
- Check the approved LT and P requirements in the eventual native UI; resolve
  conditional labels against actual native feedback. Then review the separate
  build reference. Stage 1 still requires separate authorization.

The 48 captures are simulated prototype renders. They do not prove native
Discourse behavior, device layout, keyboard continuity or accessibility.

The follow-up [native source audit and proposed build-reference composition](19-composer-v4-native-audit-and-proposed-build-reference.md)
records what the pinned Discourse commit supports and what still requires
target-version runtime proof. It is not a reference approval.
