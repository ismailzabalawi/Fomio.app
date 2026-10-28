# Reporting & Safety design review

Recorded: 2026-10-16. Branch: `codex/discourse-reporting-ia`.

## User-directed sequence

1. Create and review complete IA, wireframes and mockups.
2. Apply the accepted design’s backend configuration/contracts properly and validate them with controlled accounts.
3. Build and validate the native SwiftUI feature.

*(2026-10-16 status, superseded; see [current status](stage-gates.md#current-status--2026-10-18).)* Native implementation was explicitly paused before any app code changes. This stage authorizes design artifacts only; no site settings, reporting/Ignore mutations or backend/app feature changes have been made.

**2026-10-17 update:** the user approved the designs and requested the implementation handoff. All five Claude Design pages (`Safety Mockups`, `Backend & Native Handoff`, `Safety IA & Wireframes`, `Safety Prototype`, `SafetyPhone`) were read from the cloud project; `support.js` was noted as the shared prototype runtime. Implementation follows the approved visual and flow intent plus verified contracts, not the prototype runtime. Read-only stage-2 contract confirmation followed (see [stage gates](stage-gates.md#stage-2-status--2026-10-17)). The user then paused native implementation until controlled-account validation, and kept site settings unchanged.

See [stage gates and backend/native handoff](stage-gates.md) for the proposed work after design acceptance.

## Claude Design project

[Fomio Reporting & Safety Design](https://claude.ai/design/p/24874719-7fed-43f6-b2ba-265fe76556f6). Created using the selected Fomio Design System on 2026-10-16. The first design review set has been generated. It is a draft for product review, not accepted implementation guidance. Prototype interaction repair remains in progress; see the findings below.

## Claude Design brief

The user authorized Claude Design. A new project was requested at `https://claude.ai/design`, using the already selected **Fomio Design System** and Mobile app design template. The existing Fomio IA project is a reference, not a modification target. The full design prompt was submitted as one pasted-text attachment with a short instruction to produce all four deliverables:

- **Safety IA & Wireframes**: stable screen IDs, information architecture, low-fidelity layouts and journeys.
- **Safety Mockups**: polished native-style iPhone and iPad screens, light/AMOLED dark, large text and representative Arabic/RTL.
- **Safety Prototype**: clickable fictional flows with scenario controls outside product UI, no live network writes.
- **Backend & Native Handoff**: behavior dependencies, proposed configuration, evidence status, copy sheet and validation checklist.

The brief includes the following constraints from [reporting IA](../../reporting-safety-ia.md) and [Ignore assessment](../../ignore-blocking-assessment.md): use **Ignore user**, never mislabel it Block; report and Ignore are independent; reasons and permissions are Discourse-owned; guest sign-in never submits; uncertain writes never retry automatically; new members are currently ineligible to Ignore under the observed TL2 setting; proposed logged-in eligibility remains a backend decision; Forever follows Discourse’s existing convention; staff/public-access exceptions remain honest; OP/quote hiding requires client work. No invented support addresses/URLs, response deadlines, reporter history, moderation console or compliance guarantee.

## Requested coverage inventory

| IDs | Wireframe/mockup coverage |
| --- | --- |
| R01–R02 | Visible post/reply menu and conditional discussion-wide report target |
| R03–R04 | Server reason selection, exact context, required details, keyboard and validation |
| R05–R06 | Submitting/double-tap protection, confirmed receipt and optional separate Ignore |
| R07–R08 | Already reported/handled, unavailable/denied/deleted target and support path |
| R09–R11 | Guest return, expired auth, rate limit/offline, ambiguous receipt, edited-report cancellation |
| I01–I02 | Profile entry, self/staff restrictions, effects/limits, duration and explicit Ignore |
| I03–I04 | Confirmed state, ignored OP/reply/quote placeholders and temporary reveal |
| I05–I06 | Ignored users management, loading/empty/failure/refresh, Stop ignoring and restore |
| I07–I08 | New-member restriction, denied/expired/uncertain writes, profile-abuse support escalation |
| H01–H04 | Me entry, guest/member Safety & Help, policy/contact resource dependencies and Report vs Ignore explanation |
| P01–P02 | Existing composer integration: filtered/rejected and pending review, retained writing |
| O01–O02 | Designer-facing moderator delivery/service map, filtering text/link/media, operations/contact gates |
| A01–A03 | iPad adaptation, large text with keyboard, RTL and non-color-only failure states |

Requested coverage is not evidence that every state has been generated or reviewed. Record actual files, findings and gaps below after generation.

## Design references and review criteria

Use the selected current Fomio design system; established fallback is purple/white and AMOLED with system sans type. Native iOS 26+ bars, menus and sheets; centered readable content on iPad. No unrelated redesign. Fictional sample content and server-reason catalog are identified in reviewer annotations. Contact/policy content stays a resource dependency rather than an invented working destination.

Apple guidance consulted for this pass: [Menus](https://developer.apple.com/design/human-interface-guidelines/menus), [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets), [Action sheets](https://developer.apple.com/design/human-interface-guidelines/action-sheets). Use consistent menu icon treatment, a focused form sheet for report details, and action-related choices in native confirmation dialogs. Browser mocks do not establish native HIG/accessibility acceptance.

Review each output for exact-target preservation, honest report receipt and permissions, separate Ignore, contact availability for guests, input recovery, cancel/back, 44pt targets, keyboard safety, narrow/large-text/iPad/RTL layout and no technical backend text in product screens. Moderator operations remain in Discourse’s existing web workflow; filtering and staffing are real backend/operations gates, not decorative native screens.


## Generated review set and actual findings

The cloud project contains these pages:

- `Safety IA & Wireframes.dc.html`: inventory and wireframe/user-flow reference. Claude reports seven flow maps; full independent flow-by-flow review remains pending.
- `Safety Mockups.dc.html`: indexed Reporting, Ignore user, Safety & Help, Recovery, AMOLED dark and iPad/accessibility sets. The report reason sheet was independently viewed in unselected/selected states; target author/reply context, reason list, Send state and non-removal copy render. This is representative browser evidence, not exhaustive acceptance.
- `Safety Prototype.dc.html`: scenario-driven prototype draft. Independent browser clicks on the profile shortcut and reply More menu did not visibly change state. This was sent to Claude for repair. Do not describe the clickable journeys as verified.
- `Backend & Native Handoff.dc.html`: evidence classes, service/operations map, configuration decisions, tests, copy sheet and stage gates. Content was inspected through the browser. Operational facts and sample UI values still require backend validation.
- `SafetyPhone.dc.html`: shared visual screen component, not a separate native app implementation.

The mockup index enumerates R01–R11 and subvariants, I01–I08 and subvariants, H01–H04, P01–P02, A01–A03 and subvariants, and six dark-flow examples. The full requested inventory above remains the review checklist; generation and index presence alone are not a pass for each state.

Corrections requested during review: (1) collapse ignored profile Recent activity rather than expose the post excerpt; Claude reports this corrected, but final independent click-through remains pending; (2) eliminate temporary debug pages/output and repair embedded rendering; (3) repair unresponsive prototype controls and verify actual journeys rather than relying on screenshots. Claude’s checker also identified that lower mockup frames remained blank and reported a loading repair. Repeat representative lower-board checks before approval.

`claude-design-initial-review.zip` is the original archive exported through Claude Design’s Project HTML export during review. It preserves all five pages, shared assets/runtime and the state at export time. It is an **initial snapshot**, not a claim to contain the latest cloud repairs. Its `shots/` directory includes temporary debug captures; they are archival diagnostics, not accepted mockups. `prototype-initial-preview.jpg` is the clean exported initial prototype preview; no interaction pass is implied.

No backend setting, Ignore/report mutation or SwiftUI feature code was changed. Backend configuration and native implementation remain behind the user’s design-review stage. Review the wireframes and mockups, resolve interaction/layout/copy issues and explicit product decisions, then take up the backend stage described in [stage gates](stage-gates.md).
