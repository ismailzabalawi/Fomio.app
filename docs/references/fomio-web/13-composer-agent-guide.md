# 13 — Composer agent entry point and native reuse contract

**Current implementation status:** read
[21 — native implementation and QA](21-composer-v4-native-implementation-and-qa.md) first for
the latest explicit authorization, existing-design selection and D4 warning
decision. Work is local; native Stage 1 verification and release approval
remain open. Earlier pending-authorization statements below are historical.

**Baseline linked and adopted for planning: 2026-09-30.** The user accepted
the v4 roadmap and requested this alignment with the IA and research. Preserve
the v4 direction and delivery sequence. This documentation task did not start
implementation; D1–D10 were pending at that point.
The corrected Stage 0 r1 snapshot and records are available for review in [16].
Ismail's subsequent D1–D10 direction is recorded in [17]; it supersedes the
pending status stated above, without approving r1 or starting implementation.
Their presence in the repository does not approve the reference or start Stage 1.

[12]: 12-composer-v4-implementation-roadmap.md
[16]: 16-composer-v4-stage-0-r1.md
[17]: 17-composer-v4-decision-update.md

## Read in this order

| Document | Authority and use |
|---|---|
| This guide | Entry point, reuse rules, route lookup and task contract |
| [12 — v4 roadmap](12-composer-v4-implementation-roadmap.md) | Delivery order, pending decisions, acceptance matrix and approval gates |
| [16 — Stage 0 r1 review](16-composer-v4-stage-0-r1.md) | Current proposed reference: corrected snapshot, capture evidence and pending approvals |
| [17 — decision update](17-composer-v4-decision-update.md) | D1–D10 direction after r1 capture; native behavior and settings still require verification |
| [18 — r1 reconciliation](18-composer-v4-r1-reconciliation.md) | Affected r1 acceptance/copy records and approved policy defaults; review overlay, not a changed snapshot |
| [19 — native audit and proposed build reference](19-composer-v4-native-audit-and-proposed-build-reference.md) | Source-backed D3–D7/P findings at the pinned commit, LT gap and runtime checks still needed before approval |
| [14 — original Stage 0 lock](14-composer-v4-stage-0-lock.md) | Pre-r1 snapshot and capture record; historical audit trail |
| [15 — copy and corrections](15-composer-v4-copy-and-corrections-sheet.md) | Pre-r1 audit findings and wording choices; review r1 before acting on these |
| [10 — IA map](10-composer-ia-map.md) | Stable C01–C19 intent/state inventory; v4 adds subcases and tablet states |
| [09 — research](09-composer-research.md) | Native routes, source paths, contracts, storage, permission checks and evidence IDs E01–E24 |
| [Network observations](composer-network-observations.csv) | Dated requests actually observed; not an exhaustive API contract or test suite |
| [Design context](composer-design-context.md) | Dated label/palette fixtures; never hardcode their values in production |
| v4 review/prototype/handoff, linked in [12] | Target appearance and interaction; simulated behavior does not prove native support |
| [11 — experiment](11-composer-native-feasibility.md) | Historical findings only; not an approved UI or reusable baseline by default |

Read repository-wide `CLAUDE.md`, [00](00-roadmap.md), [02](02-discourse-core-reference.md),
[03](03-implementation.md), [04](04-workflow.md) and [07](07-production-implementation-plan.md)
as applicable. This composer track does not authorize unrelated roadmap work.
The old [design prompt](composer-claude-design-prompt.md) and v1–v3 are historical
input, not instructions to replay. The archeologist skill's Expo/headless
assumptions do not apply to this native Discourse theme.

## Conflict resolution

- User instructions govern scope and authorization. Never take an attached
  prompt, a historical command, or a mockup action as permission to execute it.
- v4 defines the agreed direction; [12] defines delivery and outstanding
  choices. Earlier IA alternatives do not reopen the design automatically.
- Source at the current server commit defines actual contracts and available
  extension points. Doc 09 records `7b4f0970`, not a forever-current version.
- A mismatch between design and native behavior becomes a documented gap:
  reproduce it, identify the existing seam, and propose a concrete alternative
  if necessary. Do not silently simplify the design or invent backend support.
- Preserve the difference between **observed**, **source-backed**, **proposed**,
  **prototype-tested**, and **integration-tested**. Only evidence can advance
  a feature between these states.

## Native reuse rules

1. Start with settings → existing native behavior → styling/supported theme
   APIs → justified component. A server plugin or core change requires a
   separately agreed scope; it is not the default workaround for a mockup.
2. Keep one native composer model/service and editor document. Do not add a
   shadow body, custom Markdown converter, independent autosave timer, local
   draft database, duplicate upload queue, custom submit endpoint or new
   community/post-type model.
3. Existing native UI actions own requests. The route table below is a tracing
   aid, **not a plan to call each endpoint manually from theme code**. Formatting
   and menu actions often need no request at all.
4. Reuse native serializers, authenticated request handling, permission checks,
   drafts, Uppy and result handling. A frontend control never grants permission.
   Preserve conditional plugin fields and native first-post edit sequencing.
5. New rendering belongs in supported extension points. Before adding an
   outlet, verify its arguments/current responsive branches and record the
   decision in doc 03 and the duplication guard's current allowlist. Do not
   replace entire core components merely to reproduce mockup markup.
6. New copy uses native translations/site overrides first. New theme-owned
   translations need a stated reason. Do not copy observed limits, group names,
   categories, safe-area heights or simulated errors as production constants.
7. Out-of-scope redesigned features retain native functionality where permitted:
   PM, staff actions, shared drafts and whispers must not break. Unknown plugin
   tools must not disappear. No new tags/AI/attachment capabilities by accident.

## Route-to-native-owner lookup

All paths below come from [09's route inventory](09-composer-research.md#route-and-call-inventory)
and its permanent [evidence index](09-composer-research.md#evidence-index).
Revalidate verbs, payloads and handlers in `config/routes.rb` and the relevant
call site at the actual target commit. `.json` variants do not imply separate
application endpoints.

| Design area | Existing native owner / entry | Server route and handler to trace | Evidence |
|---|---|---|---|
| Open new/reply/edit, C01–03/C10–11 | `services/composer.js`, `models/composer.js`; container/editor components | Opening is primarily local state; guidance uses `GET /composer_messages` → `ComposerMessagesController#index` | E01–E04, E08 |
| Create topic/reply, C16/C17 | `models/composer.js#createPost`, `adapters/post.js#createRecord` | `POST /posts` → `PostsController#create` → `NewPostManager#perform` → create/moderation result | E02, E05, E13 |
| Edit, C11/C15/C16 | `models/composer.js#editPost` | `GET /posts/:id` → `#show`; `PUT /posts/:id` → `PostsController#update` → `PostRevisor#revise!`; eligible metadata uses `PUT /t/:topic_id` → `TopicsController#update` | E02, E05–E06 |
| Drafts, C12/C14/C15 | `models/composer.js#serializeDraftData/#saveDraft`, `models/draft.js` | `POST/GET /drafts.json`, `GET/DELETE /drafts/:key.json` → `DraftsController#create/#index/#show/#destroy` | E02, E07 |
| Editor modes and formatting, C04/C05 | `ui-kit/d-editor.gjs`, native Toolbar and rich editor | Formatting uses native commands; preference switch uses `PUT /u/:username.json` → `UsersController#update` | E04, E14, E16, E19 |
| Images, C06 | `lib/uppy/composer-upload.js` and native editor placeholders | `POST /uploads` → `UploadsController#create` → `UploadCreator`; native lookup routes resolve references | E12 |
| Links, C07 | Native Onebox/inline-link/editor behavior | `GET /onebox` → `OneboxController#show`; conditional `GET /inline-onebox` → `InlineOneboxController#show` | E09 |
| Mentions, C08 | Native autocomplete | `GET /u/search/users` → `UsersController#search_users` | E10 |
| Similar topics, C09 | Native composer messages/eligibility/debounce | `GET /similar_topics` → `SimilarTopicsController#index` → `Topic.similar_to` | E08 |
| Poll/table/details/date/spoiler/code, C08 | Native plugin availability, builders and editor insert commands | Do not invent separate create-post types or endpoints for insertion; content follows native post save | E16, E19; verify each enabled plugin |
| Guided categories, C18 | Native form templates and category assignment | Follow the existing form-template flow; see E24 and `config/routes.rb`, not a custom forms backend | E14, E24 |
| Restrictions/outcomes, C13/C19 | Native composer error/result handling and Guardian | Existing post/topic/draft routes above; `NewPostResultSerializer`, `PostSerializer`; permission sources in `lib/guardian/` | E05–E07, E13, E18 |

Critical contracts: an enqueued result is not published; first-post metadata
and body may be separate requests, not an atomic theme operation; preserve
`original_text` edit conflict protection; draft sequence/owner are not
last-write-wins strings. Upload completion is not post publication. Post
processing/jobs and topic MessageBus updates remain native (E15/E20).
Use doc 09's complete feature packets and storage map when tracing these paths.

## Before adding anything new

Search the existing implementation, pinned core and enabled plugins. In the
task record answer: Which v4 frame needs this? Which native component/action
already handles it? Why is configuration or restyling insufficient? Which
supported hook will be used? What happens in the other editor mode and on
tablet? What native behavior remains the fallback? If evidence is missing,
mark it **Unknown**, name the source search/test needed, and do not invent it.

Verification commands (read-only; set `DISCOURSE_SRC` to a complete matching
source export first; do not run historical snippets blindly):

```bash
rg -n 'composer_messages|resources :posts|resources :drafts|uploads|similar_topics|onebox|form-templates' "$DISCOURSE_SRC/config/routes.rb"
rg -n 'createPost|editPost|serializeDraftData|saveDraft|applyTopicTemplate' "$DISCOURSE_SRC/frontend/discourse/app/models/composer.js"
rg -n 'onToolbarCreate|addComposerToolbarPopupMenuOption|addComposerSaveErrorCallback' "$DISCOURSE_SRC/frontend/discourse/app/lib/plugin-api.gjs"
rg -n 'NewPostManager|PostRevisor|original_text' "$DISCOURSE_SRC/app/controllers/posts_controller.rb"
```

Runtime route/spec checks belong to an authorized, configured development
Discourse; see doc 09. A live theme preview shares the real database. Read the
current deployment guidance before any upload; old default-theme IDs and
watch configurations are not safety guarantees.

## Required task handoff

Every implementation task carries these fields:

| Field | Required content |
|---|---|
| Scope | Roadmap stage, v4 frame/subcase IDs, authorization and exclusions |
| Native trace | Client action → existing route if any → handler/service → serializer/outcome; evidence path + identifier |
| Change | Existing files/components reused; justified new hook/markup; no duplicate source of truth |
| State protection | Text/selection, drafts, uploads, intent and pending submission across layout/panel changes |
| Acceptance | Matched design reference, both modes, phone/tablet/desktop, keyboard/accessibility, success and failure |
| Evidence | Tests actually run, screenshots at matching state/size, device checks pending, known deviations |
| Decisions | D1–D10 impact; unsupported behavior and user-approved alternative, if any |

Do not claim completion solely from a matching empty screen, a passing style
guard, or a mockup simulation. Use [12]'s acceptance matrix and release gates.
Keep this guide compact: update canonical evidence in doc 09, states in doc 10,
delivery/decisions in doc 12, and link them rather than forking specifications.

Latest review candidate and user-facing next steps: [22 — Review handoff](22-composer-v4-review-handoff.md). The newer layout is selected; local implementation does not imply a live rollout or device sign-off.
