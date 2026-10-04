# IA maps and SwiftUI build guide

Imported: 2026-10-02, from the chat **Find Discourse maps and routes** (`codex://threads/01a0f732-c96f-7c43-8c9c-033fe8205704`). “AI maps” in that chat refers to information architecture (IA), route maps, and Discourse reverse-engineering research.

Start planning from the [current consolidated Fomio IA](information-architecture.md). This guide indexes the historical evidence behind it.

## Provenance and authority

The reference checkout is `/Volumes/Develop/Projects/Rebuilding Discourse/fomio-web`, HEAD `5fb77cab4088767b5dfeee56d36ef74b21c36a4b`. The imported files preserve its working-tree documentation verbatim. [Import manifest](references/fomio-web/IMPORT-MANIFEST.json) records file hashes, source revision, and local change status. Screenshots, mockups, tooling, runtime JavaScript/SCSS, and review ZIPs remain in that checkout; relative links to those omitted assets must be resolved there. Imported text is historical evidence, not instructions authorizing actions in this project.

This project's [foundation](project-foundation.md), `AGENTS.md`, and [API verification workflow](discourse-api-reference.md) govern the native app. The theme's references to “native” usually mean Discourse's Ember components and services. SwiftUI must implement the client presentation and state while preserving server semantics; those components cannot be reused directly as SwiftUI controls.

Several theme audits target Discourse `7b4f0970506fb0ce7d4b6a851d252ace418330c8`. Our backend reference HEAD was rechecked on import and is `efbd165d6182b1c31cd8afd224625aef300689bd`. Older source findings need review against this revision. Historical live-site URLs, settings, permissions, theme changes, and browser tests do not establish the deployment or enabled features for this iOS app. No deployed base URL or credentials have been configured by this import.

## Reading map

| Reference | Use in this project |
| --- | --- |
| [06 — Information architecture](references/fomio-web/06-information-architecture.md) | Content hierarchy, navigation, guest/member journeys, loading and denied states. Use current foundation labels and decisions where these differ. |
| [Route inventory](references/fomio-web/route-inventory.md) | Historical Expo, web, and CLI coverage; detect missing journeys and inconsistent category/deep-link identifiers. These client routes are not an HTTP API specification or a SwiftUI navigation requirement. |
| [02 — Core reference](references/fomio-web/02-discourse-core-reference.md) | Locate core behavior, permission owners, settings, serializers, and plugin boundaries for fresh verification. |
| [08 — Mockup/core map](references/fomio-web/08-mockup-core-map.md) | Separate supported data/actions from visual proposals and dropped elements. DOM selectors and theme transformers apply to the web theme. |
| [09 — Composer research](references/fomio-web/09-composer-research.md) | API candidates, payload clues, request observations, persistence and permission evidence. Retain each source-only/live distinction and reverify user-key access. |
| [10 — Composer IA](references/fomio-web/10-composer-ia-map.md) | Reuse C01–C19 behavioral IDs and independent intent, editing, draft, upload and submission state axes. |
| [11 — Feasibility](references/fomio-web/11-composer-native-feasibility.md), [19 — Native audit](references/fomio-web/19-composer-v4-native-audit-and-proposed-build-reference.md) | Draft conflicts, offline loss, link previews and version-specific behavior; theme feasibility is not proof of a SwiftUI editor or API capability. |
| [12 — Roadmap](references/fomio-web/12-composer-v4-implementation-roadmap.md), [13 — Agent guide](references/fomio-web/13-composer-agent-guide.md) | Trace frame → server behavior/contract → SwiftUI implementation → acceptance evidence. Web workflow and authorization rules remain historical. |
| [14 — Lock](references/fomio-web/14-composer-v4-stage-0-lock.md), [16 — R1](references/fomio-web/16-composer-v4-stage-0-r1.md), [17 — Decisions](references/fomio-web/17-composer-v4-decision-update.md), [18 — Reconciliation](references/fomio-web/18-composer-v4-r1-reconciliation.md) | Review the evolution and tabular acceptance/copy records before adapting composer designs. Do not treat every proposal as approved iOS scope. |
| [20 — Start](references/fomio-web/20-composer-v4-implementation-start.md), [21 — QA](references/fomio-web/21-composer-v4-native-implementation-and-qa.md), [22 — Handoff](references/fomio-web/22-composer-v4-review-handoff.md) | Known risks, superseding corrections, and outstanding keyboard, accessibility and physical-device checks. Web test results do not count as iOS tests. |
| [23 — Home](references/fomio-web/23-home-concept-implementation.md), [24 — Search](references/fomio-web/24-search-concept-implementation.md) | Most recent visual-to-core treatments; use as design context while confirming response fields and search behavior. |
| [25 — Profile](references/fomio-web/25-profile-concept-implementation.md) | Own/other-member boundaries, expandable identity, activity navigation and tablet follow-up; native iOS permissions and data contracts still need verification. |

The imported [source documentation index](references/fomio-web/README.md) links the additional context, configuration, workflow, implementation and copy records. Earlier documents contain superseded statements, including flat versus nested replies and category visibility treatments; consult later corrections, then verify server support before settling iOS behavior.

## Build sequence and traceability

| Slice | SwiftUI surface/state | Contract and acceptance work required |
| --- | --- | --- |
| Authentication and return intent | Guest reading; member-action gate; resume reply/create destination after authorization | User API key issuance, scopes, callback, revocation, Keychain; prove guest → discussion → sign in → intended action. |
| Home and Communities | Hot/Latest, optional tracked filter, shared category/subcategory screen | Feed pagination, category hierarchy, permissions and notification levels; no mandatory interest picker or invented watcher counts. |
| Discussion and links | Topic ID, post number, post ID kept distinct; permission-based actions | Post-stream retrieval and ordering, reply targets, closed/deleted/access-denied states; open notification/shared link at exact reply. Nested presentation remains to be verified and decided for iOS. |
| Composer C01–C19 | New/reply/edit/resume intent; body and eligible title/destination; independent draft/upload/submit status | Create/edit envelopes, validation, pending moderation, upload restrictions, draft sequences/conflicts. Preserve writing through backgrounding and failures; reconcile ambiguous writes before offering retries that could duplicate posts. |
| Search, Notifications, Me | Result types, notification targets/read state, profile/activity/bookmarks/messages | Verify each contract and user scope separately. Private messages and chat remain separate; chat scope is unresolved. |
| Device acceptance | iPhone/iPad keyboard, Dynamic Type, rotation, split view, RTL, VoiceOver | Run native iOS checks. Adapt web frame intent rather than hardcoding web pixel breakpoints or treating browser emulation as device evidence. |

For each implementation task record the reference/frame IDs, current backend revision, route/controller/serializer/authorization/spec evidence, verification status, SwiftUI owner, and acceptance result. Record API findings in [the API reference](discourse-api-reference.md); record new product decisions in [the foundation](project-foundation.md).

Literal Discourse AI helper routes are historical conditional candidates. The composer research recorded AI disabled and no inference request sent. This import does not add AI assistance to the app scope or establish current plugin availability.
