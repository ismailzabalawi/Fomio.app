# fomio-web docs

Reference for anyone — human or agent — picking this theme up cold. Read in
order the first time; after that, jump to what you need.

**Composer agents start with [13 — Composer agent guide](13-composer-agent-guide.md).**
The linked v4 roadmap, IA and native research form one planning baseline;
pending decisions and implementation authorization remain explicit.

| Doc | Read it when |
|---|---|
| [00 — Roadmap](00-roadmap.md) | Always first. The phases, the redesign rule, the launch gate |
| [01 — Context and decisions](01-context-and-decisions.md) | Before changing direction or scope — what's locked, what was superseded |
| [02 — Discourse core reference](02-discourse-core-reference.md) | Before writing any selector, variable or transformer — verified facts with file paths |
| [03 — Implementation](03-implementation.md) | Before adding code — what exists, and what `archive/v0` has worth lifting |
| [04 — Workflow](04-workflow.md) | To run, check, preview or ship the theme |
| [05 — Phase 1 configuration](05-phase-1-configuration.md) | Configuring the site, and the open product questions |
| [06 — Information architecture](06-information-architecture.md) | Planning the screen map and core journeys before wireframing |
| [07 — Production implementation plan](07-production-implementation-plan.md) | Turning the mockup pack into a native-first, verified Discourse theme |
| [08 — Mockup to core map](08-mockup-core-map.md) | Before building a screen from the mockups — each element's core source, and what's open |
| [Route inventory](route-inventory.md) | Mapping a screen across the old clients (mobile app, first web theme, CLI). Reference only |
| [09 — Composer research](09-composer-research.md) | Exact-version routes, live request observations, persistence, permissions and customization boundaries |
| [10 — Composer IA map](10-composer-ia-map.md) | Composer journeys, state maps and the frame inventory for later wireframes/mockups |
| [11 — Composer native feasibility](11-composer-native-feasibility.md) | Opt-in native Format prototype, tablet matrix, source boundaries and remaining blockers |
| [12 — Composer v4 implementation roadmap](12-composer-v4-implementation-roadmap.md) | Design lock, native feasibility gates, delivery stages and frame-by-frame acceptance; planning only |
| [13 — Composer agent guide](13-composer-agent-guide.md) | Start here for composer work: document authority, existing routes/owners and rules against unnecessary replacements |
| [14 — Composer v4 Stage 0 lock](14-composer-v4-stage-0-lock.md) | Frozen reference, capture evidence and open approval checklist; pending review |
| [15 — Composer v4 copy and corrections](15-composer-v4-copy-and-corrections-sheet.md) | Proposed design fixes and copy choices; not approved |
| [16 — Composer v4 Stage 0 r1 review](16-composer-v4-stage-0-r1.md) | Corrected design snapshot, 48 captures and updated records; proposed reference, pending approval |
| [17 — Composer v4 decision update](17-composer-v4-decision-update.md) | Ismail's D1–D10 direction after r1; native behavior and settings need verification before reference approval |
| [18 — Composer v4 r1 reconciliation](18-composer-v4-r1-reconciliation.md) | Exact r1 record/copy impact of D1–D10 and Ismail's approved policy defaults; build reference still pending |
| [19 — Composer v4 native audit and proposed build reference](19-composer-v4-native-audit-and-proposed-build-reference.md) | Pinned-source findings for D3–D7, P-1–P-4 and LT; review composition and remaining runtime gates |
| [20 — Composer v4 implementation start](20-composer-v4-implementation-start.md) | First local implementation slice, user-approved offline warning, deferred safeguard and native testing gate |

**State as of 2026-09-26:** restarted. `main` has the applied Phase 1
configuration record, the Phase 2A mobile bottom bar and the first shell
variables, built from the Claude Design screen pack (08). The first pass is on
`archive/v0`. Phase 0 is locked. 2B category context and the 2C Tracked filter
are built (08); 2D states are checked and native, with one empty-state fix. The 2A bar is checked signed in, with five fixes. 2E is done: phones get core's tabs as a scrolling row. Phase 2's remaining items are the Tracked-on-Hot/Top decision and external device checks (07). Unified New is on for the site (2026-09-27): unread topics live under New › Replies, and the shell is verified against it (02, 07). Phase 3 (3A–3E) was audited and signed off on 2026-09-27 (07). Phase 4 started on 2026-09-30: the visitor empty state is implemented; members will choose categories and build their own tracked feeds, with no onboarding picker or separate Explore screen. Theme 36 was briefly the site default during the accidental watcher upload; the user has restored theme 31. See the current status in [00 — Roadmap](00-roadmap.md) and [07 — Production plan](07-production-implementation-plan.md).

**The rule, restated:** we don't redesign a Discourse screen because it looks
like Discourse; only when it materially affects the primary Fomio
experience. And before writing any value, find where Discourse already
holds it.

Latest composer implementation evidence: [21 — native implementation and QA](21-composer-v4-native-implementation-and-qa.md).

Current review handoff: [22 — Composer v4 review handoff](22-composer-v4-review-handoff.md), with local screenshots, review archive and remaining real-device gates.
