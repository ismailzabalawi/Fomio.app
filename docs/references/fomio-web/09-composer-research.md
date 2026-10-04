# Composer research — Fomio

Research date: 2026-09-28 (Asia/Amman). Analysis and design preparation only; no theme implementation or deployment. Companion: [information architecture and wireframe brief](10-composer-ia-map.md).

**Agent alignment, 2026-09-30:** this is the native evidence reference for the
v4 [roadmap](12-composer-v4-implementation-roadmap.md) and [agent guide](13-composer-agent-guide.md).
Read the guide first. The evidence below remains dated; aligning documents
does not turn source-only paths into live tests or proposals into supported
APIs. The route inventory is for tracing native actions, not creating a second
theme API client. Re-check the target server commit/settings before coding.

## Decision

Fomio can substantially customize the composer’s presentation, hierarchy, contextual guidance, toolbar, and creation entry points while retaining Discourse’s composer service, editor, draft protocol, uploads, validation, and save pipeline. Start with native settings and theme styling; add a small theme component only for missing experience elements. Use a server plugin when a requirement needs new persisted fields, authoritative validation, new permissions, or a new workflow. No core patch is justified by this research.

This is a recommendation, not approval to implement every available feature. The current project is a native Discourse web theme, not the Expo/headless client described by the older archeologist skill. The skill’s evidence-tracing method applies; its mobile-client assumptions do not replace this repository’s architecture. Existing terminology overrides remain unchanged.

## Evidence and environment

- Live browser: `https://meta.fomio.app/latest?preview_theme_id=36`, authenticated account; theme stylesheet IDs 36 and 37 observed.
- Live generator: **2026.8.0-latest**, commit **7b4f0970506fb0ce7d4b6a851d252ace418330c8**.
- Source: that exact commit exported from `/Volumes/Develop/Projects/Fomio/discourse` to `/tmp/fomio-composer-core`. The older working checkout was not changed.
- “Development mode” here means the development theme preview with CDP Network/Runtime inspection. The server is still the real Fomio backend, not a local Rails development database. Previewing a theme does not sandbox drafts, preferences, uploads, or posts.
- Exercised: new-topic composer, category chooser, Markdown/rich-text switching, autosave, mentions, hashtags, similar topics, Onebox, save/close/resume/discard, reply opening, edit opening/cancel, desktop and 390×844 responsive layout.
- A clearly named research draft was created, restored, and discarded; DELETE returned 200. The original empty reply and edit were closed. No post was published or edited. The editor preference was restored to its initial Markdown value (`composition_mode: 0`). No site settings were changed.
- Existing unrelated draft was left alone. No credentials, cookies, request headers, or full response bodies are stored in this report. Network evidence is summarized in [composer-network-observations.csv](composer-network-observations.csv).
- Not exercised: posting/uploading, private messages, approval queues, real permission failures, simultaneous editors, offline recovery, physical phone keyboard/safe areas, signed-out/ordinary-member roles, dark/RTL variants. These remain source-backed or unverified, not live passes. Browser error log query returned no errors at the inspection checkpoint.

Source references below are relative to the exported core tree at the pinned commit. The [evidence index](#evidence-index) provides permanent commit links; line numbers refer to that version. “Observed” means captured in this session; “source” means code inspected but the action was not executed.

## Configuration observed on 2026-09-28

| Capability | Evidence today | Design implication |
|---|---|---|
| Category destination | Default `4` (General), uncategorized disabled; category chooser includes hierarchy, descriptions and a lock for Staff | Always show destination; inherit category context; do not invent a second community data model |
| Editor | Account started in Markdown; rich-text switch works; switching sends `PUT /u/:username.json` | Support both modes. A site default does not override existing user preference. `default_composition_mode` is not a client-exposed setting here; its current server value was not re-read |
| Tags | `tagging_enabled: false` | Exclude tags from v1 frames; treat them as a future conditional surface |
| Poll | `poll_enabled: true`; “Build poll” appears in Options in both modes | Poll can be a native insertion flow, not a new backend post type |
| Form templates | `enable_form_templates: true`, `show_preview_for_form_templates: true` | Native structured forms are an available path; category assignment and real form behavior were not tested |
| AI helper | `discourse_ai_enabled: false`, `ai_helper_enabled: false` | Do not depict working AI assistance in the baseline mockup |
| Composer redesign | `enable_composer_redesign: false`; source marks it **conceptual** | Do not depend on it as a stable shortcut |
| New composer actions | `enable_new_composer_actions: true`; source marks this flag stable | Action menu and overall redesign are separate flags |
| Limits | Client settings: title minimum 5, body minimum 2, body maximum 32,000; similar-title threshold 10 | Read settings and native errors; do not hardcode these numbers into the design implementation. Additional server/context rules still apply |
| Uploads | Authorized extensions shown to the client: jpg, jpeg, png, gif, heic, heif, webp, avif, svg, jxl; S3/direct-S3 flags false | Current baseline is image-oriented. Do not promise video/audio/general attachments from core capability alone |

Settings evidence: live read of the site-settings service; mode evidence: current-user option and captured requests. Source: `config/site_settings.yml` (`default_composition_mode`, `enable_composer_redesign`, `enable_new_composer_actions`, `enable_form_templates`), `ui-kit/d-editor.gjs#toggleRichEditor/#saveRichEditorPreference` [E14, E16].

## Route and call inventory

The composer is primarily an application overlay/state machine, not a page with one `composer#create` endpoint. `GET /new-topic`, `/new-message`, and `/share-target` are entry routes; ordinary New/Reply/Edit buttons open the composer service on the current page. Both new topics and replies create a post through `POST /posts`. [E01, E02, E03]

| Trigger | Verb + route | Main handler / contract | Coverage |
|---|---|---|---|
| Open new/reply/edit | `GET /composer_messages` | `ComposerMessagesController#index`; `composer_action`, conditional `topic_id`, `post_id`; `composer_messages` envelope | Observed 200 in all three modes |
| Type title/body | `GET /similar_topics?title=…&raw=…` | `SimilarTopicsController#index` → `Topic.similar_to`; frontend sends title + first 200 body characters after eligibility/debounce checks | Observed 200 and suggestions UI |
| Autosave | `POST /drafts.json` | `DraftsController#create`; `draft_key`, `sequence`, JSON-string `data`, `owner`, `force_save`; success + `draft_sequence` | Observed 200 |
| List drafts | `GET /drafts.json?offset=0&limit=30` | `DraftsController#index`; `{drafts:[…]}`; conditional categories for lazy loading | Observed 200; resume restored title/body/category |
| Fetch a draft by key | `GET /drafts/:key.json` | `DraftsController#show`; `{draft, draft_sequence}` | Source; this resume used already loaded draft data |
| Discard/cancel | `DELETE /drafts/:key.json` | `DraftsController#destroy`; draft key and sequence | Observed 200 for research new-topic and inspected topic draft |
| Switch editor | `PUT /u/:username.json` | `UsersController#update`; `composition_mode` persisted by d-editor | Observed 200 twice; initial mode restored |
| `@` autocomplete | `GET /u/search/users` | `UsersController#search_users`; `term`, `category_id`/topic context, `include_groups`, `limit`; `{users,groups}` | Observed 200 |
| `#` autocomplete | `GET /hashtags/search.json` | `HashtagsController#search` → `HashtagAutocompleteService`; `{success,results}` | Observed 200 with `order[]=category` |
| Resolve hashtags in preview | `GET /hashtags` | `HashtagsController#lookup`; `slugs[]`, `order[]` | Observed 200 |
| Standalone link preview | `GET /onebox?url=…&refresh=…` | `OneboxController#show`; rendered preview content | Observed 200 for public discourse.org URL |
| Inline link preview | `GET /inline-onebox` | `InlineOneboxController#show` | Source; distinct conditional path |
| Open existing post for edit | `GET /posts/:id` | `PostsController#show`; post JSON including `raw`, `cooked`, `version`, permissions | Observed 200 |
| Create topic / reply / PM | `POST /posts` | `PostsController#create` → `NewPostManager`; native client asks for result envelope using `nested_post: true` | Source; not submitted |
| Save body edit | `PUT /posts/:id` | `PostsController#update` → `PostRevisor`; nested `post` payload; conflict may return 409 | Source; not submitted |
| Edit first-post topic metadata | `PUT /t/:topic_id` | `TopicsController#update`; title/category/tags/featured link as eligible | Source; native edit can do this **before** post update |
| Upload local file | `POST /uploads` | `UploadsController#create` → `UploadCreator`; multipart `upload_type=composer` and file, then UploadSerializer | Source; not uploaded |
| Resolve upload refs | `POST /uploads/lookup-urls`, `/uploads/lookup-metadata` | `UploadsController#lookup_urls/#metadata` | Source; conditional content path |
| Direct/S3 upload alternatives | `POST /uploads/generate-presigned-put`, `/complete-external-upload`; multipart create/batch-presign/complete/abort routes | UploadsController actions; storage-provider transfer also involved | Source; not current enabled path |
| Reply/edit presence | `GET /presence/get`; `POST /presence/update` | PresenceController; channels `/discourse-presence/reply/:topic_id`, `/discourse-presence/edit/:post_id` | GET observed 200; update source-only |
| Realtime transport | MessageBus long-poll transport | MessageBus middleware, not a normal composer route in `routes.rb` | Ancillary; no claim of full channel capture |
| Form creation | `GET /form-templates`, `/form-templates/:id` | `FormTemplatesController#index/#show` | Source; enabled but not exercised |
| Tags if enabled | `GET /tags/filter/search` | `TagsController#search` | Source; off in current UI |
| AI if enabled later | `POST /discourse-ai/ai-helper/suggest`, `/suggest_title`, `/suggest_category`, `/suggest_tags`, `/stream_suggestion` | Plugin engine → `DiscourseAi::AiHelper::AssistantController` | Source; disabled; no inference request sent |

Routes: `config/routes.rb:613,686,1129–1142,1287,1427–1429,1467,1484–1485,1551–1555,1688–1697,1794,1962–1973`; AI plugin `config/routes.rb:13–18,92`. [E01, E07, E08, E09, E10, E11, E12, E21]

This is a core composer call map, not a claim to have observed every conditional request. Some editor actions are local: formatting, moving the cursor, opening menus, and preview cooking do not inherently need a bespoke HTTP request. Poll/details/date insertions ultimately become post content. Page navigation, topic reading/timings, analytics, lazy-loaded JavaScript, images and fonts are ancillary, and are excluded from the composer API count.

## Feature packet — publishing and editing

**Goal:** Preserve Discourse’s complete posting semantics while giving Fomio control over the creation experience.

**Entry Point:** `POST /posts`, `PUT /posts/:id`, conditional `PUT /t/:topic_id`; `app/controllers/posts_controller.rb#create/#update`, `topics_controller.rb#update`; routes [E01].

**Client Trigger:** `services/composer.js` controls opening/saving/outcomes; `models/composer.js#save/#createPost/#editPost` builds state and payload; `adapters/post.js#createRecord` sends JSON with `nested_post: true`. Rendering lives in `components/composer-container.gjs`, `composer-editor.gjs` and `ui-kit/d-editor.gjs`. [E02–E05]

**Server Path:** `PostsController#create` → `NewPostManager#perform` → moderation handlers or `PostCreator#create` → `TopicCreator` for a new topic plus Post creation. Editing goes through Guardian and `PostRevisor#revise!`. Server cooking is in `Post#cook`; post-processing may later update cooked content. First-post editing can update topic metadata and then post body as two client requests; do not replace this with a naive single PUT or promise atomicity across the pair. [E05, E06, E15]

**Data Map:** `topics` owns title/category/archetype/visibility; `posts` owns raw/cooked/body version and reply relationship. Upload references, drafts, revisions and reviewables are distinct persistence concerns; see the schema table below. [E17]

**Permissions:** Login required for creation/update. `Guardian#can_create_topic_on_category?`, `#can_create_post_on_topic?`, `#can_create_post?`, `#can_edit_post?` incorporate category, topic, user and role conditions. PostCreator validates; Post includes create/day rate limits, while PostRevisor applies edit limiting and slow-mode logic. The theme may explain restrictions but cannot grant permission or enforce a security rule by hiding a control. [E05, E06, E18]

**Async Side Effects:** `PostJobsEnqueuer#enqueue_jobs` schedules post alerts, featured users, post-processing and tracking updates; mailing-list notification job is delayed by configured email window. Paths vary for import, PM and action posts. `PostRevisor#post_process_post/#alert_users` covers edit processing/alerts. Do not equate “saved” with “all media/cooked content/background work finished.” [E15]

**Realtime Side Effects:** `Post#publish_change_to_clients!` publishes to `/topic/:topic_id` with id, post number, editor/user, type and version; topic statistics and tracking publication are separate. Audience restrictions are preserved by `publish_message!`. Presence is its own plugin/service channel system, not live collaborative text editing. [E15, E20]

**Serializer/JSON Contract:** `NewPostResultSerializer` conditionally emits `action`, `success`, `post`, `errors`, `pending_count`, `pending_post`, `message`, `reason`, `route_to`; `PostSerializer`/`BasicPostSerializer` provide identifiers, raw/cooked, version and permission fields. `reason` is staff-conditional. A successful result can be **enqueued for approval**, not published. Native service handles `action === "enqueued"` and route overrides. Update returns `{post: …}` with raw and draft sequence, plus conditional extra data. Never assume every optional key exists. [E05, E13]

**Tests:** `spec/requests/posts_controller_spec.rb`: “returns a valid JSON response when the post is enqueued” (1283), stale `original_text` → 409 (647–650), “rolls back post changes when a first-post title edit is invalid” (714). `frontend/discourse/tests/acceptance/composer-edit-conflict-test.js`: original_text omitted for new replies and included for edits. These tests were read, not run. [E22]

**Safest Extension Plan:** Native settings first; theme styling and supported JS extension points second; server plugin for persistent custom metadata, business validation or workflow. Core patch only after demonstrating a missing hook and proposing an upstream hook. Keep core’s current-user auth/session/CSRF behavior; this theme does not need a new API-key client.

**Verification Steps:** See the reproducible commands at the end (source/route/spec verification). Runtime specs require a configured development Discourse at the pinned commit.

### Request sketches — illustrative, not a substitute for native serialization

```json
{"title":"A useful discussion","raw":"Post body","category":4,"archetype":"regular","nested_post":true}
```

That represents a new topic. A reply instead identifies `topic_id`, supplies `raw`, and optionally `reply_to_post_number`. A PM uses `archetype: "private_message"` plus `target_recipients` and corresponding authorization. Native serialization additionally carries eligible draft, locale, typing, tag, featured-link and plugin fields. [E02: `_create_serializer`, E05: `create_params`]

```json
{"post":{"raw":"Revised body","original_text":"Original body","edit_reason":"Clarification"}}
```

That illustrates post editing. Retain conflict checks and the separate eligible topic update; do not strip `original_text` to make a conflict disappear. [E02: `editPost`, E05: `update`]

## Feature packet — drafts and recovery

**Goal:** Preserve work across closing, navigation, errors and concurrent sessions.

**Entry Point:** `POST /drafts.json`, `GET /drafts.json`, `GET/DELETE /drafts/:key.json`; `DraftsController#create/#index/#show/#destroy`. [E07]

**Client Trigger:** `models/composer.js#serializeDraftData/#saveDraft` and `models/draft.js#save/#saveBeacon/#get/#clear`. Core has closed/open/saving/draft/fullscreen states; form content and reply targets live beyond a visible textarea. [E02, E07]

**Server Path:** DraftsController validates size/JSON/count and calls `Draft.set`; draft sequence and owner govern conflict/ownership. Edit autosave can report original body/title/tag conflicts. [E07]

**Data Map:** `drafts(user_id,draft_key,data,sequence,owner,revisions)`, `draft_sequences(user_id,draft_key,sequence)`; Draft belongs to User and may reference uploads. Draft data includes reply, action, title, categoryId, tags, archetype, recipients, original content and reply target. [E02, E17]

**Permissions:** Requires login; draft ownership and sequence checks; limits apply. This is not a simple last-write-wins text field. [E07]

**Async Side Effects:** Client debouncing and unload beacon are separate from Sidekiq. No per-save Sidekiq dependency was established in this trace; do not invent one.

**Realtime Side Effects:** Draft sequence/owner conflicts are handled by the draft protocol; do not describe draft saving as collaborative text synchronization. Presence is separate. [E07, E20]

**Serializer/JSON Contract:** Save returns `success`, `draft_sequence` and conditional `conflict_user`; errors can carry conflict/limit descriptions. Index uses DraftSerializer; show returns `draft` and `draft_sequence`. The frontend already distinguishes saving, conflict, offline and unsaved status. [E02, E07]

**Tests:** `drafts_controller_spec.rb`: raw/title/tag conflicts, “cant trivially resolve conflicts without interaction”, “has a clean protocol for ownership handover”, “raises an error for out-of-sequence draft setting”, maximum-drafts failure. `composer-draft-saving-test.js`: “Shows a warning if a draft wasn't saved”. Read, not executed. [E22]

**Safest Extension Plan:** Keep native autosave/restore/close/discard. A clearer status placement or draft-resume affordance is theme work. Any new composer field needs explicit draft serialization as well as create/update serialization; a DOM-only field is insufficient. [E19]

**Verification Steps:** Source-search Draft/saveDraft; inspect Rails draft routes; run focused draft request specs as listed below.

## Storage map

| Data | Authoritative columns / associations | Why the mockup needs it |
|---|---|---|
| Topic | `topics.title`, `category_id`, `archetype`, `visible`, `closed`, `archived`; Topic belongs to Category and has posts | Destination and visibility are meaningful, not decoration |
| Post | `posts.topic_id`, `user_id`, `post_number`, `raw`, `cooked`, `reply_to_post_number`, `version`; Post belongs to Topic/User | Reply/edit intent and source/rendered distinction |
| Personal draft | `drafts.data`, `draft_key`, `sequence`, `owner`, `user_id`; separate `draft_sequences` | Restore, conflict, saved/unsaved, multiple drafts |
| Upload | `uploads.url`, `original_filename`, `filesize`, `width`, `height`, `extension`, `secure`; polymorphic `upload_references` | Upload is independent from publishing; permission/storage behavior matters |
| Revision | `post_revisions.post_id`, `user_id`, `modifications`, `number`, `hidden` | Edit reason/history and conflicts |
| Moderation | `reviewables.type`, `status`, `payload`, `topic_id`, `category_id`, `created_by_id` | Pending approval is its own terminal UI state |
| Extra topic data | `topic_custom_fields.topic_id`, `name`, `value` | Needs registration, authorization, persistence and serialization; a theme label is not a schema |
| Guided forms | `categories.topic_template`; `form_templates`; `category_form_templates.category_id/form_template_id` | Prefer existing category templates/form assignments before custom forms |

Schema source: `db/structure.sql:1532,1601,1704,2340,5141,5173,5558,7895,8516,10042,10760,10793`. Associations: `app/models/{post,topic,draft,upload}.rb`. [E17]

## Customization ceiling

All rows are design options, not committed scope. “Theme” still means preserving native services/components, translations and server truth.

| Experience | Maximum sensible approach | Boundary / cost |
|---|---|---|
| Layout, spacing, width, typography, surfaces | Theme CSS around native `#reply-control` and composer classes | Preserve resizer/fullscreen, focus order, safe areas and phone keyboard behavior. Current theme already aligns hidden-preview dock and raises minimized strip [E23] |
| Community-first creation | Inherit category, show identity/guidance, reorganize title/destination visually | Core selects permitted categories. Current bottom bar already calls `openNewTopic({category})`; never hardcode category lists [E02, E23] |
| Clearer copy and hints | Site text/i18n; `customizeComposerText` and placeholder transformer where conditional | Existing overrides are the current vocabulary source; do not silently rename them [E19] |
| Simplified toolbar | Native Options grouping; `onToolbarCreate` and `addComposerToolbarPopupMenuOption` for justified tools | Both modes, keyboard shortcuts, overflow and supported content must stay usable; a Markdown-only button may need a rich-editor path [E19] |
| Link/image/poll creation intents | Lightweight entry shortcuts feeding the same native composer and body representation | Not automatically different topic archetypes. Preserve typed content when switching intent; use Onebox/Uppy/poll tooling [E04, E09, E12] |
| Community-specific prompts | Native category `topic_template`; enabled native form templates for stronger structure | Category changes should not overwrite a user’s body: core `applyTopicTemplate` protects nonempty content. Form-template flow needs its own proof [E02, E24] |
| Live preview and guidance | Restyle native preview/messages; reduce interruption and preserve dismissed state | Rich text is already the rendered editing surface; do not force a second preview onto it [E04, E08] |
| Attachments | Reuse Uppy pipeline; improve insertion/progress/error presentation; upload preprocessor/Markdown resolver hooks | Current authorized extensions are image types. Storage authorization, secure uploads, quotas and conversion stay server-owned [E12, E19] |
| Custom rich blocks, slash-like commands | Possible via `registerRichEditorExtension`: nodes/marks, parse/serialize, input rules, keymaps, commands, node views | API explicitly **experimental**. Must round-trip Markdown and render safely on server/mobile/CLI. A JS editor node alone does not create a valid stored format [E16, E19] |
| Additional structured fields | Native forms first; otherwise theme inputs plus small server plugin | Need allowed params/custom fields, validation, drafts, create/update/read serializer contracts and editor reopening [E05, E19, E24] |
| AI title/rewrite/category help | Existing Discourse AI plugin before custom integration | Disabled today; enabling/configuring model, permissions and product behavior is separate work. No working AI button in baseline [E21] |
| Shared drafts/editorial workflow | Native shared-draft feature if configuration/roles fit; plugin for genuinely different workflow | Shared drafts are not personal drafts and not simultaneous collaborative editing [E01, E02] |
| Full-screen creation experience | First prototype native fullscreen + themed hierarchy; add scoped UI only if needed | A custom replacement editor/page inherits draft, mobile, accessibility, plugin and validation maintenance. No need demonstrated |
| New visibility model, scheduling, collaborative editing, independent media-post model | Product-specific backend analysis/plugin | Not established as theme-only capabilities by this trace. Do not include as assumed controls |

### Verified extension seams

- `api.customizeComposerText({actionTitle,saveLabel,saveIcon,titlePlaceholder})` returns native/localized values; `api.addComposerAction` registers an action-menu item. [E19]
- `api.onToolbarCreate`, `api.addComposerToolbarPopupMenuOption`, `api.addComposerUploadPreProcessor`, `api.addComposerUploadMarkdownResolver`. [E19]
- `api.composerBeforeSave` and `api.addComposerSaveErrorCallback` exist. Pre-save checks can improve experience, but are not authoritative server validation. [E19]
- `api.serializeToDraft`, `serializeOnCreate`, `serializeOnUpdate`, `serializeToTopic` transmit registered model state. They do **not** automatically permit or persist it on Rails. Server seams include `add_permitted_post_create_param`, `register_editable_topic_custom_field`, `add_to_serializer`, and post create/edit events. [E05, E19]
- Transformers found: `composer-open`, `composer-apply-topic-template`, `composer-editor-reply-placeholder`, `composer-force-editor-mode`, `composer-save-button-label`, `composer-message-components`, `composer-service-cannot-submit-post`. Confirm callback contracts at call site before implementation. [E02, E04, E19]
- Outlets found: `composer-open`, `composer-action-after`, `before-composer-controls`, `before-composer-fields`, `after-composer-title-input`, `after-composer-category-input`, `after-composer-tag-input`, `after-title-and-category`, `composer-fields`, `composer-after-composer-editor`, `composer-fields-below`, `composer-after-save-or-cancel`, `composer-mobile-buttons-bottom`, `before-composer-toggles`. Placement/arguments vary by responsive/redesign branch. [E03, E04]
- Repository constraint: current outlet allowlist has only `below-footer` and `category-heading`. The existence of a core outlet is not already an allowlist entry; an implementation using a composer outlet must record the decision in `docs/03-implementation.md` and update `scripts/check-duplication.sh`. This research makes no such change. [E23]

## Recommended next scope

1. **Baseline Fomio shell:** destination, title, editor, native insert/format tools, save/draft status and primary action. New-topic, reply and edit modes share the same system, with appropriate fields hidden by core intent.
2. **Fix hierarchy before adding features:** on phones separate destination and title; make the destination legible; keep the writing area dominant and secondary tools reachable. On desktop avoid guidance obscuring the text/preview. These are proposals based on the observed screens, not proven CSS fixes.
3. **One progressive enhancement:** compare a plain composer with a light Text / Image / Link / Poll entry chooser that initializes existing core behavior. Keep it only if it makes creation easier; do not require users to classify mixed-content posts.
4. **Later, category-specific forms:** Questions, Bug Reports and Feature Requests are candidate use cases, but actual templates and field requirements need product decisions. AI and custom persisted content types are separate future scope.

The companion map names all wireframe states so the mockup does not optimize only the empty happy path.

## Verification commands

Executed in this research: exact-commit export, focused `rg`/file reads, browser Network events and selected JSON-shape checks. These commands reproduce the source/route evidence:

```bash
git -C /Volumes/Develop/Projects/Fomio/discourse archive --format=tar -o /tmp/fomio-composer-core.tar 7b4f0970506fb0ce7d4b6a851d252ace418330c8
mkdir -p /tmp/fomio-composer-core
tar -xf /tmp/fomio-composer-core.tar -C /tmp/fomio-composer-core
rg -n 'composer_messages|resources :posts|resources :drafts|uploads|similar_topics|onebox|presence|form-templates' /tmp/fomio-composer-core/config/routes.rb
rg -n 'create_params|NewPostManager|PostRevisor|original_text' /tmp/fomio-composer-core/app/controllers/posts_controller.rb
rg -n 'serializeDraftData|saveDraft|applyTopicTemplate|editPost' /tmp/fomio-composer-core/frontend/discourse/app/models/composer.js
```

On a separately configured development checkout at that commit (not run here):

```bash
bin/rails routes | rg 'posts|drafts|uploads|composer_messages|similar_topics|presence'
bundle exec rspec spec/requests/posts_controller_spec.rb spec/requests/drafts_controller_spec.rb spec/requests/uploads_controller_spec.rb
```

After implementation: native theme guards, composer acceptance tests, ordinary member and staff roles, both editor modes, 390px/desktop, light/dark/RTL, keyboard and actual iOS keyboard/safe-area checks. Tests particularly relevant: composer draft-saving, edit-conflict, uploads-uppy, reply-to, form-template, mentions, onebox and composer-new acceptance files. Do not call these passed until executed.

## Evidence index

All links below pin the source inspected, not the moving default branch. `frontend/discourse/app/` is abbreviated as `app/` only in the labels.

- **E01:** [config/routes.rb](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/config/routes.rb) — Rails routing.
- **E02:** [models/composer.js](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/frontend/discourse/app/models/composer.js), [services/composer.js](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/frontend/discourse/app/services/composer.js) — states, payloads, drafts, outcomes.
- **E03:** [composer-container.gjs](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/frontend/discourse/app/components/composer-container.gjs) — shell and outlets.
- **E04:** [composer-editor.gjs](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/frontend/discourse/app/components/composer-editor.gjs), [composer-title.gjs](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/frontend/discourse/app/components/composer-title.gjs) — editor, preview and link-title behavior.
- **E05:** [PostsController](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/app/controllers/posts_controller.rb), [PostAdapter](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/frontend/discourse/app/adapters/post.js).
- **E06:** [NewPostManager](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/lib/new_post_manager.rb), [PostCreator](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/lib/post_creator.rb), [PostRevisor](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/lib/post_revisor.rb).
- **E07:** [DraftsController](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/app/controllers/drafts_controller.rb), [client Draft](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/frontend/discourse/app/models/draft.js), [DraftSerializer](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/app/serializers/draft_serializer.rb).
- **E08:** [composer-messages.gjs](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/frontend/discourse/app/components/composer-messages.gjs), [SimilarTopicsController](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/app/controllers/similar_topics_controller.rb), [ComposerMessagesController](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/app/controllers/composer_messages_controller.rb).
- **E09:** [OneboxController](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/app/controllers/onebox_controller.rb), [load-oneboxes.js](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/frontend/discourse/app/lib/load-oneboxes.js).
- **E10:** [user-search.js](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/frontend/discourse/app/lib/user-search.js).
- **E11:** [HashtagsController](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/app/controllers/hashtags_controller.rb), [hashtag-autocomplete.js](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/frontend/discourse/app/lib/hashtag-autocomplete.js).
- **E12:** [UploadsController](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/app/controllers/uploads_controller.rb), [UploadSerializer](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/app/serializers/upload_serializer.rb), [UppyComposerUpload](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/frontend/discourse/app/lib/uppy/composer-upload.js).
- **E13:** [NewPostResultSerializer](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/app/serializers/new_post_result_serializer.rb), [PostSerializer](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/app/serializers/post_serializer.rb).
- **E14:** [site_settings.yml](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/config/site_settings.yml).
- **E15:** [PostJobsEnqueuer](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/lib/post_jobs_enqueuer.rb), [Post](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/app/models/post.rb), plus PostRevisor E06.
- **E16:** [d-editor.gjs](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/frontend/discourse/app/ui-kit/d-editor.gjs), [rich-editor-extensions.ts](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/frontend/discourse/app/lib/composer/rich-editor-extensions.ts).
- **E17:** [db/structure.sql](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/db/structure.sql), [models directory](https://github.com/discourse/discourse/tree/7b4f0970506fb0ce7d4b6a851d252ace418330c8/app/models).
- **E18:** [PostGuardian](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/lib/guardian/post_guardian.rb), [TopicGuardian](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/lib/guardian/topic_guardian.rb).
- **E19:** [plugin-api.gjs](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/frontend/discourse/app/lib/plugin-api.gjs), [Ruby Plugin::Instance](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/lib/plugin/instance.rb).
- **E20:** [discourse-presence/plugin.rb](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/plugins/discourse-presence/plugin.rb).
- **E21:** [Discourse AI routes](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/plugins/discourse-ai/config/routes.rb), [AssistantController](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/plugins/discourse-ai/app/controllers/discourse_ai/ai_helper/assistant_controller.rb).
- **E22:** [request specs](https://github.com/discourse/discourse/tree/7b4f0970506fb0ce7d4b6a851d252ace418330c8/spec/requests), [composer acceptance tests](https://github.com/discourse/discourse/tree/7b4f0970506fb0ce7d4b6a851d252ace418330c8/frontend/discourse/tests/acceptance).
- **E23:** This repository: `common/common.scss:315,436`, `javascripts/discourse/api-initializers/fomio-bottom-bar.gjs:105–126`, `scripts/check-duplication.sh`, `docs/00-roadmap.md`, `docs/08-mockup-core-map.md`.
- **E24:** [FormTemplatesController](https://github.com/discourse/discourse/blob/7b4f0970506fb0ce7d4b6a851d252ace418330c8/app/controllers/form_templates_controller.rb), Composer#applyTopicTemplate E02, schema E17, `composer-form-template-test.js` E22.
