# Fomio MVP design handoff

Recorded: 2026-10-03. Status: finalized browser mockup baseline for native implementation planning. No SwiftUI app has been scaffolded and no deployment or API contract was verified by this design work.

This document records the launch scope and visual decisions from the wireframe and Liquid Glass mockup reviews. It narrows the broader [information architecture](../information-architecture.md) for the MVP; deferred IA surfaces remain future scope, not launch requirements. Discourse remains authoritative for content, permissions, validation and moderation.

## Design references

The [Claude Design project](https://claude.ai/design/p/4e5074c6-0b81-4e0d-a216-04b839117fec) contains the source mockups. Start with [MVP Prototype](https://claude.ai/design/p/4e5074c6-0b81-4e0d-a216-04b839117fec?file=Fomio+MVP+Prototype.dc.html), then the project files Fomio MVP Review Index, Fomio MVP Visual System, Fomio MVP Screen Pack and Fomio Visual QA. FomioPhone is the shared browser component. Overview, Screens, Core Flows, Composer States, Flow Completion and iPad Accessibility retain the wireframe references.

The earlier user-supplied wireframe archive is `/Users/ismailzabalawi/Downloads/Fomio iOS IA & Wireframes.zip`. It predates the final mockup corrections. The final Claude HTML and licensed photo files have not been exported into this repository; the cloud project remains the editable reference. Do not confuse the earlier ZIP with the finalized design.

## Launch scope

| Route or action | MVP treatment |
| --- | --- |
| Home | One discussion feed with community context, compact text/photo rows and search access. Latest is the mockup choice; production initial sort remains to be confirmed. |
| Communities | Flat directory with modest identity fallback, descriptions, parent/child hierarchy and scoped Find communities. Initially limit visible children, then expand. Recent-discussion previews are conditional on verified data. |
| Community and subcommunity | Shared discussion-list grammar, parent context and contextual Create inheriting the destination. |
| Discussion | Opening post and replies; Reply, Quote, Like, Save and Share in context. Preserve topic, post and reading context. Exact reply navigation requires a verified post-stream contract. |
| Create and Reply | Minimal title where required, body, permitted destination, photo affordance and explicit draft exit choices. Global Create chooses a destination; contextual Create inherits it. |
| Search | Discussion results and exact destinations. Keep global discussion search distinct from the directory's local community filter. |
| Notifications | Replies and mentions, unread cues, exact target and unavailable-target treatment. Push transport is separate. |
| Me | Basic own profile, Saved, Drafts and sign out. Other-member profile uses basic identity and recent content. |

Private messages, chat, AI, advanced activity/settings, advanced filters, tracking controls, multiple editor modes and plugin-specific insertion tools are deferred. No mandatory interest picker, invented membership/Join behavior, rankings, Reddit votes/downvotes or karma. Fomio is a community discussion alternative to Reddit, while preserving Discourse's Like semantics.

Loading, empty, offline, denied, validation, expired authorization, pending moderation and unconfirmed-write recovery remain necessary MVP states. Visual examples do not establish live availability or persistence guarantees.

## Native visual direction

Target iOS 26+ Liquid Glass from the start. Use native SwiftUI navigation and controls where suitable. Glass belongs to the functional navigation/control layer; feed and discussion content stays flat and readable. Browser blur is illustrative and must not become a substitute for native materials. Preserve the genuine Fomio wordmark and system sans typography for app content.

The mockup hierarchy uses approximately 17pt body/feed titles, 22pt discussion titles, 15pt excerpts and 13pt metadata. Implement semantic text styles with Dynamic Type rather than fixed mockup sizes. Important controls have at least 44pt equivalent targets. Keep content and actions reachable above navigation, safe areas and the keyboard. Regular glass is the default, with opaque Reduce Transparency and stronger Increase Contrast treatments.

iPad regular width uses a sidebar and a centered reading column capped at 620pt; compact layouts retain the same content hierarchy. This is a browser composition, not evidence of native split-view behavior.

Apple references: [Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility), [Layout](https://developer.apple.com/design/human-interface-guidelines/layout), [Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars), and [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass). These are implementation references, not a claim of certified HIG compliance.

### Fomio colors

Source: local web theme snapshot dated 2026-09-30, under `/Volumes/Develop/Projects/Rebuilding Discourse/fomio-web/docs/composer-v4-stage-0-r1/composer-v4-reference/2026-09-30-r1/tokens/color-schemes.css`. This records brand provenance, not deployed-site validation.

| Role | Light | AMOLED dark |
| --- | --- | --- |
| Text | #1B1A1F | #ECEBF0 |
| Background | #FFFFFF | #000000 |
| Accent | #5B3FD6 | #A58FFF |
| Secondary accent | #4A2FBF | #BFAFFF |
| Highlight | #E7E0FF | #2B2257 |
| Selected | #EEEBFA | #1B1826 |
| Hover | #F4F3F7 | #111114 |
| Danger | #C62D3A | #FF6B78 |
| Success | #1D7F4A | #4CD48A |
| Love | #D6245C | #FF5C8D |
| On accent | #FFFFFF | #000000 |

Do not substitute Claude's default cream/terracotta palette. States must remain understandable without color alone.

## Interaction and recovery requirements

- Retain each tab's stack, community/topic/post identity, search query and reading position. Authentication restores intent and rechecks permissions; it never automatically posts.
- Keep title, body and destination through appearance/text-size changes and composer exits. Dismissal offers Keep editing, Keep draft or explicit Discard.
- Uploading and failed attachment states retain writing, expose recovery actions and disable Post until resolved. Before keeping a draft with an unfinished photo, explain that the photo will not be kept and offer Keep draft without photo. The draft identifies the missing photo; resume offers Add photo again or Continue without photo. This mock behavior does not promise durable storage or continued background uploading.
- Treat published, pending review, rejected and unconfirmed outcomes separately. Unconfirmed submission disables Post, offers Check again and Back, and requires a duplicate warning before manual retry. No assumed idempotency or offline queued sending.
- Saved and Drafts belong under Me. Example topic 4190/post number 14 is a fictional routing test identity; a post number is not a post ID.

## Verification and limits

The final independent browser harness run completed **117 renders with zero flags** on 2026-10-03. Cases covered Home, filtered/expanded Communities, exact reply, composer/keyboard, upload/failure, draft warning/list/resume, chooser, Notifications and Me across selected light/dark, accessibility, narrow and iPad settings. This is a representative matrix, not every possible combination or a full accessibility audit. [Machine-readable record](mockup-verification.json).

Earlier runs reported 96, then two flagged cases. Real fixes included 44pt targets, large-text heading/destination reflow, concise draft recovery with stacked actions and keyboard initially down, and the iPad width cap. Checker corrections use visible text line boxes and the active sheet/popover surface instead of hidden background or line-clamped excerpts. The remaining draft flags were resolved with scroll/click evidence and corrected measurement boundaries; failures were not simply suppressed.

Independent interactions confirmed notification navigation to topic 4190/reply 14, the pre-choice unfinished-photo warning, keeping a draft without the photo, and the resumed sample's title/body/destination recovery notice. Walnut and fig images visibly loaded. The oscilloscope image was not separately verified by Codex. Other interaction regressions were not all independently repeated on the final files.

Still required in the native build: Dynamic Type, VoiceOver, contrast and reduced-motion behavior, actual Liquid Glass rendering, keyboard/focus/scroll behavior, device safe areas, iPad resizing, RTL, background recovery and durable draft policy. Also repeat community filter/expansion Back behavior, writing through appearance changes, both photo-resume actions, guest authorization without auto-post, uncertain-write recovery, Saved/Drafts routes and upload-disabled Post.

## Sample image provenance

Claude reports three local, unedited 960px images under `assets/photos/`, with credits in its Review Index: Martin Lorenz, “Oberfläche Wohnzimmertisch.JPG” (CC BY-SA 3.0); Dave Clausen, “Rigol oscilloscope DS 1052E.jpg” (CC BY 2.0); Homoarborea, “Ficus carica (1).jpg” (CC0). These are Claude's file-page checks, not independently repeated license verification in this repository. Retrieve the exact source URLs and fulfill attribution obligations before redistributing or shipping them. Sample copy was adjusted to match the photos; unmatched oak/joinery photos were removed.

The [generated walnut fallback](assets/README.md) is saved locally but was not used in the final mockup because a matching licensed photo was available. All discussions, authors and identities are illustrative content.

## Implementation handoff

1. Export the final Claude project and photo credits into a versioned local reference snapshot before reproducing screens. Keep source wireframes separate.
2. Read the [API verification workflow](../discourse-api-reference.md), recheck the backend revision and verify contracts through routes, controllers, serializers, authorization and request specs. Deployment URL, enabled plugins/settings, credentials and per-user authorization setup remain pending.
3. Build the native shell and Home → Community → Discussion → Composer slice with fixtures, preserving the above states. Verify native interactions and accessibility before treating browser QA as implementation acceptance.
4. Add verified read/write integrations and remaining MVP routes. Record contract evidence and unresolved assumptions; use per-user authorization, never an embedded administrator key.


## Native implementation follow-up — 2026-10-03

The fixture milestone is now implemented. See [implementation status and native validation](../implementation-status.md) and the [versioned export](snapshots/2026-10-03/README.md). Historical browser-render evidence above remains design evidence; live acceptance and full native release checks remain pending.

## Rebuilt composer scope — 2026-10-04

The [new snapshot](snapshots/2026-10-04/) preserves the rebuilt composer component and showcase; the previous dated snapshot remains intact. Accepted native scope: source-preserving rich/Markdown editing, multiple inline photos retained locally with unfinished drafts, native poll/table/details/spoiler/date/code forms, attributed quotes, suggestions and Onebox metadata under verified capabilities, wrapping titles, RTL/localization, adaptive toolbar and protected dismissal. The native implementation follows Apple sheet, keyboard and accessibility behavior and preserves Discourse as posting/permission authority. The mockup's unfinished-photo-loss behavior is superseded by durable local retention.
