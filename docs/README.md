# Fomio documentation map

Current native baseline: 2026-10-03. The fixture MVP is implemented; live release remains gated. These documents are checked-in developer/product handoff, not additional deployment authorization.

## Reading order

1. [Implementation status](implementation-status.md): what is delivered, actual test evidence and practical limits.
2. [Accepted plan](implementation-plan.md): decisions, MVP boundaries and required release gates.
3. [Architecture](architecture.md): composition, source ownership, domain identity, navigation/state, transport and persistence.
4. [Development guide](development-guide.md): prerequisites, build/test, development scenarios and pending configuration.
5. [Flows and recovery](flows-and-recovery.md): observable screen/auth/thread/composer/draft/photo behavior.
6. [API reference](discourse-api-reference.md): source revision, evidence, response shapes and unresolved deployment contracts.
   [Localization strategy](localization-strategy.md): native strings, Discourse terminology contract, cache, and offline fallback.
   [Localization implementation plan](localization-implementation-plan.md): live admin readiness findings, English-only fallback, and ordered delivery gates.
   [Discourse integration plan](discourse-integration-plan.md): staged live verification and the first authentication gate.
7. [Release readiness](release-readiness.md): automated coverage, native/live acceptance and required resources.
   [App Store submission](app-store-submission.md): current blockers, public-policy findings, listing/review drafts and packaging preflight.

## Design and historical references

- [iPad readiness](ipad-readiness.md) tracks the native adaptive implementation, packaging, iPad rotation/chooser/composer evidence, and remaining narrow-window and input acceptance.

- [Adaptive reading native implementation](validation/2026-10-20-adaptive-native/README.md) records the later authorized implementation, actual regression results, corrected expectations and remaining five-layout acceptance. Earlier planning/deployment passes are preserved as dated evidence.

- [Adaptive browsing IA and API connection map](adaptive-navigation-ia-api-map.md) is the 2026-10-20 pre-implementation contract for the five-layout reading mockup: shared community scope, chooser/sidebar/directory parity, revealable search, exact-post links, endpoint and identity mapping, state ownership, source evidence, native gaps and acceptance gates. It does not change app behavior. The [scoped-search verification packet](validation/2026-10-20-scoped-search/README.md) records source tracing, 22 guest GETs, reproduced context failures, corrected request/response rules and remaining member/native gates. The [member permission follow-up](validation/2026-10-20-scoped-search/member-permissions.md) adds 14 passing isolated request tests, staff/guest restricted-category reads and positive public pagination; deployed ordinary-member checks require a non-staff account. The [operator/error follow-up](validation/2026-10-20-scoped-search/operators-and-errors.md) records 42 passing isolated cases and five guest reads, search settings/minimum validation, error recovery and the unresolved server failure signal.

- [Explicit database-search error fix](validation/2026-10-20-search-database-error-fix/README.md) records the authorized local Discourse patch: a safe grouped error replaces silent database-query failures, with 359 passing examples, lint and real PostgreSQL probes. The [deployment packet](validation/2026-10-20-search-error-deployment/README.md) records rollout on the actual `821e9e2…` base, 305 aligned examples, isolated deployed failure checks, public HTTPS smoke checks, rebuild-hook limits and rollback. The [native grouped-error contract](adaptive-navigation-ia-api-map.md#native-grouped-search-error-contract) now defines adapter validation, cache admission, initial/refresh/pagination recovery, stale-response guards and five-layout accessibility acceptance. This specification review changes documentation only; separately authorized native work and actual results are tracked in the native implementation packet above.

- [SwiftUI rich text prototype](validation/2026-10-19-rich-prototype/README.md) records the Debug-only prose experiment, source-preservation guarantees, native tests and remaining migration gates. The existing composer remains in use.

- [iPhone Duo preparation](iphone-duo-readiness.md) records the adaptive layout audit, composer sizing fix, local tooling evidence and remaining fold/resize acceptance.

- [Notifications IA and integration map](notifications-ia.md) is the 2026-10-18 pre-public planning packet: inbox/types, grouped-reply destinations, read/seen/count semantics, foreground freshness, push enrollment/relay boundaries, current native gaps and delivery acceptance. Source review is distinct from deployed/device verification.
- [Notifications Claude Design handoff](design/notifications-claude-handoff.md) records the IA-based mockup brief, design destination and browser review status.
- [Category, subcategory and topic IA](category-topic-ia.md) is the focused 2026-10-06 pre-mockup map: root/child hierarchy, category-feed scope, nested/exact-reply navigation, permission and recovery states, source traces, and current native gaps. Native recommendations are proposals; source review is distinct from deployed verification.
- [Category/topic Claude Design handoff](design/category-topic-claude-handoff.md) links the new IA-based mockups and records independent browser checks, review screenshots and remaining native/deployment validation.
- [MVP design handoff](design/mvp-design-handoff.md) defines the narrowed launch direction.
- [Composer bar exploration](design/composer-bar-exploration.md) records the 2026-10-05 Expo-informed interaction proposal, Claude Bar Lab, browser checks and remaining decisions; it is not an accepted native replacement.
- [Versioned source export](design/snapshots/2026-10-03/README.md) records provenance, original hashes, Review Index repair and photo licenses. Native typography uses system fonts; exported Lora is reference-only.
- [Native captures](validation/2026-10-03/README.md) record simulator layouts; [browser evidence](design/mockup-verification.json) is design evidence only.
- [Project foundation](project-foundation.md) records origin and accepted decision updates.
- [Broader IA](information-architecture.md) retains future/historical routes; Hot, tracking, messaging and editing there are not launch commitments.
- [IA build guide](ia-build-guide.md) and [imported web references](references/fomio-web/README.md) preserve prior research. Imported source wording remains unchanged and requires fresh verification before reuse.

## Authority and maintenance

The user’s accepted decisions determine scope. Current implementation guides describe inspected code; historical maps describe proposals. Discourse determines live permissions/content/posting rules. Route existence, source review, sanitized adapter tests and deployed verification are distinct statuses.

When changing behavior, update the corresponding guide and implementation status. When changing an adapter, recheck backend revision and update API evidence/assumptions. Record validation with device/OS, selected tests, result artifacts and limitations. Do not overwrite original exports/imports or promote browser/fixture evidence to native/live acceptance. Do not document credentials or invent deployment resources.

- [Live category/topic API validation](validation/2026-10-06-live-api/README.md): native live reads, approved temporary writes/cleanup, catalog and Saved fixes, actual test results and unresolved rotation failure.
