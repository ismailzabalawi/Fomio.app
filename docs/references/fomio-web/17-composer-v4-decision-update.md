# 17 — Composer v4 decision update

**Subsequent D4 decision:** retain current native behavior and add an alert
about potentially losing unsaved writing; implement a safeguard later.
The user explicitly directed this while starting implementation; see
[20](20-composer-v4-implementation-start.md) for the warning and residual risk.
The other decisions below are unchanged.

Recorded 2026-09-30 from Ismail's direction: “D1 and 2, we can change that in
the settings later on. 3-7 let’s stick to native discourse behavior. D8-10
keep it for later.” This updates the disposition of D1–D10 in [12] without
changing the immutable [r1 Stage 0 record][16] or approving r1 as the
implementation reference.

[12]: 12-composer-v4-implementation-roadmap.md
[16]: 16-composer-v4-stage-0-r1.md

| ID | Current direction | Consequence for this phase |
|---|---|---|
| D1 | Defer tablet layout customization to a later settings review. | Keep current native/configured behavior for now. Verify what settings actually support before proposing a change. The v4 docked/full-height rule is not approved for implementation now. |
| D2 | Defer More/Options wording customization to a later settings review. | Keep native wording and existing site-text overrides for now. Do not change global wording or claim a suitable setting exists without checking. |
| D3 | Use native Discourse draft-conflict behavior. | Do not build the v4 Copy/force-save/use-other-version flow for the current scope. Document and test the actual native recovery behavior before claiming it protects work. |
| D4 | Use native Discourse behavior when closing an unsaved offline composer. | Do not build the v4 blocked-close Retry/Copy/discard flow for the current scope. Verify the native save/close outcome and represent it accurately. |
| D5 | Use native Discourse behavior when switching away from a filled guided form. | Do not add a custom answer-to-text conversion or custom switch dialog. D8 also defers form activation; preserve native behavior if forms are later enabled. |
| D6 | Use native Discourse insertion behavior for details, spoiler and code. | Do not build the v4 sheets for the current scope. Verify the actual native controls and supported content before mapping the affected frames. |
| D7 | Use native Discourse link-preview failure behavior. | Do not build the v4 quiet note/retry flow for the current scope. Retain native link handling and check failure behavior before making a claim about it. |
| D8 | Keep the guided-form activation decision for later. | Do not activate a new guided form as part of the current composer scope. The r1 design remains a conditional reference, not authorization to ship it. |
| D9 | Keep emoji discoverability for later. | Do not add or remove a custom emoji entry based on the v4 handoff now; retain existing native behavior. |
| D10 | Keep session-expiry redesign for later. | Do not build the proposed restore/manual-resubmit flow now; retain existing native behavior and document its actual outcome when verified. |

This is a **scope and product-direction record**, not evidence that the native
behavior has been tested or that D1/D2 have suitable settings. The frozen r1
snapshot and screenshots still show some v4 proposals that now differ from the
current direction. [18 — r1 reconciliation](18-composer-v4-r1-reconciliation.md)
maps those differences for review. Its supplemental acceptance/copy overlays
carry the approved direction; verify native behavior before approving a build
reference. Preserve r1 itself as evidence.

After this D1–D10 direction, Ismail approved the LT, P-1–P-4, intentional-copy
and exclusion **policies** recommended in the
[r1 reconciliation](18-composer-v4-r1-reconciliation.md). Exact native outcomes and
conditional labels require verification. Approval of a separate build
reference and Stage 1 authorization remain open. Reconcile P-1 and other copy
tied to D3–D7 with verified native behavior; no exact dialog or new string is
approved by implication.
